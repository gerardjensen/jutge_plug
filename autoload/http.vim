let s:plugindir = expand('<sfile>:p:h:h')
let s:cookie_file = s:plugindir."/cookies.txt"
let s:credentials_file = s:plugindir."/credentials.txt"

let s:system = function(get(g:, 'webapi#system_function', 'system'))
let s:submission_result_max_fetch_attempts = 5

function! http#get_cookie(...)
  let l:email = a:1
  let l:password = a:2
  let l:command = "curl -s --data \"email=".email."&password=".password."&submit=\" https://jutge.org/ -c ".s:cookie_file
  let l:res = s:system(l:command)
  if(len(l:res) == 0)
    echo "Jutge cookie updated successfully"
  else
    echo "Error signing in to jutge.org"
  endif
endfunction

function! http#check_valid_cookie()
  if(!filereadable(s:cookie_file))
    return 0
  endif

  let l:command = "curl -s https://jutge.org/ -b ".s:cookie_file 
  let l:res = s:system(l:command)
  let l:res_s = split(l:res,"\n")
  let l:title_line = res_s[11]
    
  let l:status = title_line[23:-9]
  
  return l:status == "Dashboard"
endfunction

function! http#print_valid_cookie()
  let l:is_valid = http#check_valid_cookie()
  if(l:is_valid)
    echo "Cookie is valid"
  else
    echo "Cookie is not valid!!!"
  endif
endfunction

 " TODO: check server connection before anything else if connection involved
function! http#server_available()
  let l:res = s:system("curl -s https://jutge.org/")
  return l:res != ""
endfunction

function! http#init()
  if(!http#server_available()) 
    echo "Unable to connect to Jutge"
    return -1
  endif

  if(!filereadable(s:credentials_file)) 
    echo "Credentials not set, please sign in using :JutgeSetCredentials <email> <password>"
    return
  endif

  let l:valid_cookie = http#check_valid_cookie()
  if(!l:valid_cookie)
    echo "Cookie too old, updating it"
    let l:content = readfile(s:credentials_file)
    let l:email = content[0]
    let l:password = content[1]
    call http#get_cookie(l:email,l:password)
  else 
    echo "Cookie is already valid"
  endif
endfunction

function! http#fetch_exercise_files(id)
  " TODO: check if all commands actually did something
  
  call s:system("curl -s https://jutge.org/problems/".a:id."/zip -b ".s:cookie_file." --output problem.zip")
  call s:system("unzip problem.zip")
  call s:system("rm problem.zip")
  
  call s:system("curl -s https://jutge.org/problems/".a:id."/public.tar -b ".s:cookie_file." --output ".a:id."/public_files.tar")
  call s:system("tar xf ".a:id."/public_files.tar -C ".a:id."/")
  call s:system("rm ".a:id."/public_files.tar")
endfunction

function! http#send_submission(id, submission_path, compiler_name) 
  echo "Uploading to ".a:id." the file ".a:submission_path
  let l:submission_url = s:system("node ".s:plugindir."/js/send.js ".a:id." ".s:cookie_file." ".a:submission_path." ".a:compiler_name)
  let l:submission_url = trim(l:submission_url)


  let l:i = 0 
  let l:verdict = "Unknown"

  while (l:i < s:submission_result_max_fetch_attempts)
    try 
      let l:res_page = http#fetch_html_with_cookie(l:submission_url) 
      let l:verdict = l:res_page["child"][1]["child"][17]["child"][3]["child"][1]["child"][9]["child"][1]["child"][1]["child"][1]["child"][3]["child"][1]["child"][1]["child"][3]["child"][1]["child"][1]["child"][3]["child"][1]["child"][0]
      let l:verdict = trim(l:verdict)
      break
    catch
      sleep 200m " No idea why, but busy waiting solves the issue
    endtry
    let l:i = l:i + 1
  endwhile

    echo "Verdict: " . l:verdict
endfunction

function! http#fetch_html_with_cookie(url)
  let l:command = "curl -s ".a:url." -b ".s:cookie_file 
  let l:res = s:system(l:command)
  return webapi#html#parse(l:res) 
endfunction

function! http#fetch_problems()
  let l:obj = http#fetch_html_with_cookie("https://jutge.org/problems")
  let l:body = obj["child"][1]["child"][17]
  let l:raw_content = body["child"][3]["child"][1]["child"][9]["child"]
  let l:courses_len = (len(l:raw_content)-1)/2
  let l:courses = map(range(l:courses_len), 0)
  let l:raw_index = 1
  let l:index = 0
  while(l:index < l:courses_len)
    let l:content = raw_content[l:raw_index] 
    let l:courses[l:index] = http#get_course(l:content)
    let l:index+=1
    let l:raw_index+=2
  endwhile
  return l:courses
endfunction

function! http#get_course(content)
  let l:course = {}
  let l:course_name = a:content["child"][1]["child"][1]["child"][0]
  let l:course_name = trim(l:course_name)
  let l:course_name = http#replace_accents(l:course_name)
  let l:course["name"] = l:course_name
  let l:course["lessons_visible"] = 0
  let l:course["lessons"] = {}

  let l:raw_lessons_exercices = a:content["child"][3]["child"]

  let l:raw_lessons_exercices_len = len(l:raw_lessons_exercices)
  let l:raw_index = 1
  let l:lesson_index = -1
  let l:exercice_index = 0
  let l:lesson = {}
  let l:exercices = {}
  while (l:raw_index < l:raw_lessons_exercices_len)
    let l:row_cnt = l:raw_lessons_exercices[l:raw_index]
    let l:title_box = l:row_cnt["child"][1]["child"][1]

    if (l:title_box["name"] == "b") " is lesson
      if (l:lesson_index > -1)
        let l:lesson["exercices"] = l:exercices
        let l:course["lessons"][l:lesson_index] = l:lesson
      endif
      let l:lesson_index += 1

      let l:lesson = {}
      let l:lesson_name = l:title_box["child"][1]["child"][0]
      let l:lesson_name = trim(l:lesson_name)
      let l:lesson_name = http#replace_accents(l:lesson_name)
      let l:lesson["name"] = l:lesson_name

      let l:lesson["exercices"] = {}
      let l:lesson["exercices_visible"] = 0

      let l:exercice_index = 0
      let l:exercices = {}
    elseif (l:title_box["name"] == "i") " is exercice
      let l:exercice_content = l:row_cnt["child"][1]["child"]
      let l:has_content = len(l:exercice_content) > 4
      if (!l:has_content)
        let l:raw_index += 2
        continue
      endif
      let l:status_box = l:exercice_content[1]
      let l:exercice_status = " "
      if (has_key(l:status_box, "attr") && has_key(l:status_box["attr"], "style"))
        let l:status_box_style = l:status_box["attr"]["style"]

        if (stridx(l:status_box_style, "green") != -1)
          let l:exercice_status = g:CORRECT_EXERCISE_CHECK
        elseif (stridx(l:status_box_style, "red") != -1)
          let l:exercice_status = g:INCORRECT_EXERCISE_CHECK
        else
          let l:exercice_status = g:PARTIAL_EXERCISE_CHECK
        endif
      endif
      let l:exercice_id = l:exercice_content[3]["attr"]["href"]
      let l:exercice_id = trim(l:exercice_id)
      let l:exercice_id = s:get_last_element_url(l:exercice_id)
      let l:exercice_name = l:exercice_content[4]
      let l:exercice_name = substitute(l:exercice_name, "&nbsp;", "", "")
      let l:exercice_name = trim(l:exercice_name)
      let l:exercice_name = http#replace_accents(l:exercice_name)

      let l:exercice = {}
      let l:exercice["name"] = l:exercice_name
      let l:exercice["id"] = l:exercice_id
      let l:exercice["status"] = l:exercice_status
      let l:exercices[l:exercice_index] = l:exercice
      let l:exercice_index += 1
    endif

    let l:raw_index += 2
  endwhile

  let l:lesson["exercices"] = l:exercices
  let l:course["lessons"][l:lesson_index] = l:lesson

  return l:course
endfunction

function! s:get_last_element_url(url)
    let l:url = substitute(a:url, '/\+$', '', '') " Remove the trailing slash if it exists
    let l:last_slash_pos = strridx(l:url, '/') " Find the position of the last slash
    let l:last_element = strpart(l:url, l:last_slash_pos + 1) " Get the last element by slicing the string from the last slash
    return l:last_element
endfunction

function! http#replace_accents(text)
  " These are some of the HTML special characters
  " Only parsing the Catalan, Spanish and English Language ones at the moment

  let l:substitutions = [
        \ ['&aacute;', 'á'],
        \ ['&eacute;', 'é'],
        \ ['&iacute;', 'í'],
        \ ['&oacute;', 'ó'],
        \ ['&uacute;', 'ú'],
        \ ['&agrave;', 'à'],
        \ ['&egrave;', 'è'],
        \ ['&ograve;', 'ò'],
        \ ['&iuml;', 'ï'],
        \ ['&uuml;', 'ü'],
        \ ['&ccedil;', 'ç'],
        \ ['&Aacute;', 'Á'],
        \ ['&Eacute;', 'É'],
        \ ['&Iacute;', 'Í'],
        \ ['&Oacute;', 'Ó'],
        \ ['&Uacute;', 'Ú'],
        \ ['&Agrave;', 'À'],
        \ ['&Egrave;', 'È'],
        \ ['&Ograve;', 'Ò'],
        \ ['&Iuml;', 'Ï'],
        \ ['&Uuml;', 'Ü'],
        \ ['&Ccedil;', 'Ç']
        \ ]

  let l:text = a:text
  for l:pair in l:substitutions
    let l:text = substitute(l:text, l:pair[0], l:pair[1], 'g')
  endfor
  return l:text
endfunction


