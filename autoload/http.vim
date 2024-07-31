let s:plugindir = expand('<sfile>:p:h:h')
let s:cookie_file = s:plugindir."/cookies.txt"
let s:credentials_file = s:plugindir."/credentials.txt"

let s:system = function(get(g:, 'webapi#system_function', 'system'))

function! http#get_cookie(...)
  let email = a:1
  let password = a:2
  let command = "curl -s --data \"email=".email."&password=".password."&submit=\" https://jutge.org/ -c ".s:cookie_file
  let res = s:system(command)
  if(len(res) == 0)
    echo "Cookie updated successfully"
  else
    echo "Error signing in"
  endif
endfunction

function! http#check_valid_coockie()
  if(!filereadable(s:cookie_file))
    return 0
  endif

  let command = "curl -s https://jutge.org/ -b ".s:cookie_file 
  let res = s:system(command)
  let res_s = split(res,"\n")
  let title_line = res_s[11]
    
  let status = title_line[23:-9]
  
  return status == "Dashboard"
endfunction

function! http#print_valid_cookie()
  let is_valid = http#check_valid_coockie()
  if(is_valid)
    echo "Cookie is valid"
  else
    echo "Cookie is not valid!!!"
  endif
endfunction

 " TODO: check server connection before anything else
function! http#server_available()
  let command = "curl -s https://jutge.org/" 
  let res = s:system(command)
  return res != ""
endfunction

function! http#init()
  if(!http#server_available()) 
    echo "Unable to connect to Jutge"
    return
  endif

  if(!filereadable(s:credentials_file)) 
    echo "Credentials not set, please sign in using :JutgeSetCredentials <email> <password>"
    return
  endif

  let valid_cookie = http#check_valid_coockie()
  if(!valid_cookie)
    echo "Cookie too old, updating it"
    let content = readfile(s:credentials_file)
    let email = content[0]
    let password = content[1]
    call http#get_cookie(email,password)
  else 
    echo "Cookie is already valid"
  endif
endfunction

function! http#fetch_exercise_files(id)
  " TODO: check for failed get
  
  call s:system("curl -s https://jutge.org/problems/".a:id."/zip -b ".s:cookie_file." --output problem.zip")
  call s:system("unzip problem.zip")
  call s:system("rm problem.zip")
  
  call s:system("curl -s https://jutge.org/problems/".a:id."/public.tar -b ".s:cookie_file." --output ".a:id."/public_files.tar")
  call s:system("tar xf ".a:id."/public_files.tar -C ".a:id."/")
  call s:system("rm ".a:id."/public_files.tar")
endfunction

function! http#fetch_html_with_cookie(url)
  let command = "curl -s ".a:url." -b ".s:cookie_file 
  let res = s:system(command)
  return webapi#html#parse(res) 
endfunction

function! http#fetch_problems()
  let obj = http#fetch_html_with_cookie("https://jutge.org/problems")
  let body = obj["child"][1]["child"][17]
  let raw_content = body["child"][3]["child"][1]["child"][9]["child"]
  let courses_len = (len(raw_content)-1)/2
  let courses = map(range(courses_len), 0)
  let raw_index = 1
  let index = 0
  while(index < courses_len)
    let content = raw_content[raw_index] 
    let courses[index] = http#get_course(content)
    let index+=1
    let raw_index+=2
  endwhile
  return courses
endfunction

function! http#get_course(content)
  let course = {}
  let course_name = a:content["child"][1]["child"][1]["child"][0]
  let course_name = trim(course_name)
  let course_name = http#replace_accents(course_name)
  let course["name"] = course_name
  let course["lessons_visible"] = 0
  let course["lessons"] = {}

  let raw_lessons_exercices = a:content["child"][3]["child"]

  let raw_lessons_exercices_len = len(raw_lessons_exercices)
  let raw_index = 1
  let lesson_index = -1
  let exercice_index = 0
  let lesson = {}
  let exercices = {}
  while(raw_index < raw_lessons_exercices_len)
    let row_cnt = raw_lessons_exercices[raw_index]
    let title_box = row_cnt["child"][1]["child"][1]

    if(title_box["name"] == "b") " is lesson
      if(lesson_index > -1)
        let lesson["exercices"] = exercices
        let course["lessons"][lesson_index] = lesson
      endif
      let lesson_index += 1

      let lesson = {}
      let lesson_name = title_box["child"][1]["child"][0]
      let lesson_name = trim(lesson_name)
      let lesson_name = http#replace_accents(lesson_name)
      let lesson["name"] = lesson_name

      let lesson["exercices"] = {}
      let lesson["exercices_visible"] = 0

      let exercice_index = 0
      let exercices = {}
    elseif(title_box["name"] == "i") " is exercice
      let exercice_content = row_cnt["child"][1]["child"]
      let has_content = len(exercice_content) > 4
      if(!has_content)
        let raw_index += 2
        continue
      endif
      let status_box = exercice_content[1]
      let exercice_status = " "
      if(has_key(status_box,"attr") && has_key(status_box["attr"],"style"))
        let status_box_style = status_box["attr"]["style"]

        if(stridx(status_box_style,"green") != -1)
          let exercice_status = g:CORRECT_EXERCISE_CHECK
        elseif (stridx(status_box_style,"red") != -1)
          let exercice_status = g:INCORRECT_EXERCISE_CHECK
        else
          let exercice_status = g:PARTIAL_EXERCISE_CHECK
        endif
      endif
      let exercice_id = exercice_content[3]["attr"]["href"]
      let exercice_id = trim(exercice_id)
      let exercice_id = s:get_last_element_url(exercice_id)
      let exercice_name = exercice_content[4]
      let exercice_name = substitute(exercice_name,"&nbsp;","","")
      let exercice_name = trim(exercice_name)
      let exercice_name = http#replace_accents(exercice_name)

      let exercice = {}
      let exercice["name"] = exercice_name
      let exercice["id"] = exercice_id
      let exercice["status"] = exercice_status
      let exercices[exercice_index] = exercice
      let exercice_index += 1
    endif

    let raw_index += 2
  endwhile

  let lesson["exercices"] = exercices
  let course["lessons"][lesson_index] = lesson

  return course
endfunction

function! s:get_last_element_url(url)
    " Remove the trailing slash if it exists
    let l:url = substitute(a:url, '/\+$', '', '')

    " Find the position of the last slash
    let l:last_slash_pos = strridx(l:url, '/')

    " Get the last element by slicing the string from the last slash
    let l:last_element = strpart(l:url, l:last_slash_pos + 1)

    return l:last_element
endfunction

function! http#replace_accents(text)
  " These are some of the HTML special characters
  " Only parsing the Catalan and Spanish Language ones at the moment

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


