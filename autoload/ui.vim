let s:system = function(get(g:, 'webapi#system_function', 'system'))
let g:version = "0.1"

let s:plugindir = expand('<sfile>:p:h:h')
let s:cookie_file = s:plugindir."/cookies.txt"
let s:mode = 0
" 0 -> Listing courses
" 1 -> Showing exercise

let s:CORRECT_EXERCISE_CHECK = "✔️"
let s:INCORRECT_EXERCISE_CHECK = "✗"
let s:PARTIAL_EXERCISE_CHECK = "⚖️"

function! ui#JutgeShowProblems()
  let winid = bufwinid('Jutge Problems')
  
  if(winid != -1)
    echo "JutgePlug is already running"
    return
  endif

  let s:already_on = 1

  let s:mode = 0
  let s:courses = ui#fetch_problems()

  call s:create_window()
  call s:add_mappings()
  let disp_text = ui#make_course_text()
  call s:set_init_text(disp_text) 
endfunction

function! ui#fetch_html_with_cookie(url)
  let command = "curl -s ".a:url." -b ".s:cookie_file 
  let res = s:system(command)
  return webapi#html#parse(res) 
endfunction

function! ui#fetch_problems()
  let obj = ui#fetch_html_with_cookie("https://jutge.org/problems")
  let body = obj["child"][1]["child"][17]
  let raw_content = body["child"][3]["child"][1]["child"][9]["child"]
  let courses_len = (len(raw_content)-1)/2
  let courses = map(range(courses_len), 0)
  let raw_index = 1
  let index = 0
  while(index < courses_len)
    let content = raw_content[raw_index] 
    let courses[index] = ui#get_course(content)
    let index+=1
    let raw_index+=2
  endwhile
  return courses
endfunction

let s:match_ids = []
let s:course_lines = [] " Lines where the title of a course is

function! ui#make_course_text() 
  let disp_text = "JUTGE VIM PLUGIN v".g:version."\n\nEnrolled courses:\n\n"
  let s:course_lines = map(range(len(s:courses)), 0)
  let index = 0
  let courses_len = len(s:courses)
  let current_line = 5
  let courses_added = 0
  while(index < courses_len)
    let course = s:courses[index]
    let disp_text = disp_text."\t * ".course["name"]."\n"
    let s:course_lines[courses_added] = current_line
    let courses_added = courses_added + 1
    let current_line = current_line + 1

    if(course["lessons_visible"])
      let lessons_len = len(course["lessons"])
      let lindex = 0
      while(lindex < lessons_len)
        let lesson = course["lessons"][lindex]
        let disp_text = disp_text."\t\t\t > ".lesson["name"]."\n"
        let current_line = current_line + 1

        if(lesson["exercices_visible"])
          let exercices_len = len(lesson["exercices"])
          let eindex = 0
          while(eindex<exercices_len)
            let exercice = lesson["exercices"][eindex]

            let disp_text = disp_text."\t\t\t\t\t ".exercice["status"]." ".exercice["name"]."\n"
            let current_line = current_line + 1
            let eindex += 1
          endwhile
        endif

        let lindex+=1
      endwhile
    endif

    let disp_text = disp_text."\n"
    let current_line = current_line + 1
    let index += 1
  endwhile

  call ClearHighlights()

  for line in s:course_lines
    call add(s:match_ids, matchaddpos('CourseText', [[line]]))
  endfor

  call s:highlightTitleChecks()
  
  return disp_text
endfunction

function! ClearHighlights()
  for id in s:match_ids
    call matchdelete(id)
  endfor
  let s:match_ids = []
endfunction

function! ui#get_course(content)
  let course = {}
  let course_name = a:content["child"][1]["child"][1]["child"][0]
  let course_name = trim(course_name)
  let course_name = ui#replace_accents(course_name)
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
      let lesson_name = ui#replace_accents(lesson_name)
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
          let exercice_status = s:CORRECT_EXERCISE_CHECK
        elseif (stridx(status_box_style,"red") != -1)
          let exercice_status = s:INCORRECT_EXERCISE_CHECK
        else
          let exercice_status = s:PARTIAL_EXERCISE_CHECK
        endif
      endif
      let exercice_id = exercice_content[3]["attr"]["href"]
      let exercice_id = trim(exercice_id)
      let exercice_id = s:get_last_element_url(exercice_id)
      let exercice_name = exercice_content[4]
      let exercice_name = substitute(exercice_name,"&nbsp;","","")
      let exercice_name = trim(exercice_name)
      let exercice_name = ui#replace_accents(exercice_name)

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

function! ui#replace_accents(text)
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

highlight GreenText ctermfg=Green guifg=Green
highlight RedText ctermfg=Red guifg=Red
highlight YellowText ctermfg=Yellow guifg=Yellow
  
highlight TitleText ctermfg=Blue guifg=Blue ctermbg=NONE guibg=NONE
highlight CourseText ctermfg=DarkGreen guifg=DarkGreen ctermbg=NONE guibg=NONE
function! s:create_window()
  vertical botrigh 90new                            " create a new window on the right that's 60 columns wide

  setlocal nomodifiable                             " stop the user from editing the buffer
  setlocal buftype=nofile bufhidden=wipe noswapfile " tell Vim this is a temporary buffer not backed by a file
  setlocal nonumber cursorline wrap nospell         " no line numbers, wrapping, highlight the current line

  call s:highlightTitleChecks()

  file Jutge Problems                                     " set the file name of the buffer
endfunction

function! s:highlightTitleChecks()
  call matchadd('GreenText', s:CORRECT_EXERCISE_CHECK)
  call matchadd('RedText', s:INCORRECT_EXERCISE_CHECK)
  call matchadd('YellowText', s:PARTIAL_EXERCISE_CHECK)

  call matchaddpos('TitleText',[1])
endfunction

function! s:set_init_text(disp_text)
  setlocal modifiable

  let lines = split(a:disp_text, '\n')

  call append(0, lines)
  
  setlocal nomodifiable
endfunction

function! s:add_mappings()
  nmap <silent> <buffer> q :bd<CR>
  nmap <silent> <buffer> <Enter> :call <SID>handle_enter()<CR>
endfunction

function! s:handle_enter_list_courses()
  setlocal modifiable
  let line_enter = line('.')
  let column_enter = col('.')

  silent! normal! gg"_dG

  let res = s:update_courses_vis(line_enter)
  if(res == -1)
    let disp_text = ui#make_course_text()

    let lines = split(disp_text, '\n')
    call append(0, lines)

    call cursor(line_enter, column_enter)
  else
    call ui#show_problem(res)
  endif

  setlocal nomodifiable

endfunction

function! s:handle_enter()
  if(s:mode == 0)
    call s:handle_enter_list_courses()
  elseif(s:mode == 1)
    call s:handle_enter_show_exercise()
  endif
endfunction

function! s:update_courses_vis(line)
  let c_line = 5
  if(a:line < c_line)
    return -1
  endif
  let course_index = 0
  let lesson_index = -1
  let exercice_index = -1

  let courses_len = len(s:courses)

  while(c_line < a:line)
    let course = s:courses[course_index]
    let course_vis_lines = ui#get_course_vis_lines(course)

    if(a:line > c_line + course_vis_lines)
      let c_line += course_vis_lines + 1
      let course_index += 1

      if(course_index >= courses_len)
        return -1
      endif 
    else
      if(lesson_index + 1 >= len(course["lessons"]))
        return -1
      endif
      let lesson = course["lessons"][lesson_index+1] 
      let lesson_vis_lines = ui#get_lesson_vis_lines(lesson)

      if(c_line + lesson_vis_lines < a:line)
        let c_line += lesson_vis_lines
        let lesson_index += 1

        if(lesson_index >= len(course["lessons"]))
          return -1
        endif
      else
        if(c_line + 1 == a:line)
          let lesson_index += 1 
          break
        endif
        let lesson_index += 1

        let exercice_index += a:line - c_line -1
        break
      endif
    endif
  endwhile

  if(lesson_index == -1)
    let s:courses[course_index]["lessons_visible"] = !s:courses[course_index]["lessons_visible"]
  elseif(exercice_index == -1)
    if (s:courses[course_index]["lessons_visible"] && lesson_index < len(s:courses[course_index]["lessons"]))
      let s:courses[course_index]["lessons"][lesson_index]["exercices_visible"] = !s:courses[course_index]["lessons"][lesson_index]["exercices_visible"]
    endif
  else
    return s:courses[course_index]["lessons"][lesson_index]["exercices"][exercice_index]["id"]
  endif

  return -1
endfunction

function! ui#get_course_vis_lines(course)
  if(!a:course["lessons_visible"])
    return 1
  endif

  let lessons = a:course["lessons"]
  let lessons_line_sum = 0
  let lessons_cnt = len(lessons)

  let lindex = 0
  while(lindex < lessons_cnt)
    let lesson = lessons[lindex]
    let lessons_line_sum += ui#get_lesson_vis_lines(lesson)

    let lindex+=1
  endwhile

  return 1 + lessons_line_sum
endfunction

function! ui#get_lesson_vis_lines(lesson)
  if(!a:lesson["exercices_visible"])
    return 1
  endif

  let exercices = a:lesson["exercices"]
  let exercices_cnt = len(exercices) 
  return 1 + exercices_cnt
endfunction

function! ui#show_problem(id)
  let s:mode = 1
  let disp_text = ui#fetch_exercise_mk_text(a:id)

  call ClearHighlights()

  let lines = split(disp_text, '\n')
  call append(0, lines)
endfunction

function! ui#fetch_exercise_mk_text(id)
  let s:current_problem_id = a:id
  let obj = ui#fetch_html_with_cookie("https://jutge.org/problems/".a:id."/")

  let body = obj["child"][1]["child"][17]
  let content = body["child"][3]["child"][1]
  let title = content["child"][5]["child"][1]["child"][2]
  let title = trim(title)

  let text = "> ".title."\n\n"
  
  let problem_status = content["child"][9]["child"][1]["child"][1]["child"][1]["child"][1]["child"][0]
  let problem_status = trim(problem_status)
  let text = text.problem_status."\n\n"

  let problem_description = content["child"][9]["child"][3]["child"][3]["child"][3]["child"][3]["child"][3]["child"]
  " let tar_file_url = problem_description["child"][1]["child"][5]["attr"]["href"]
  " let tar_file_url = "https://jutge.org".trim(tar_file_url)
  
  let element_index = 1

  let n = len(problem_description)

  while element_index < n
    let desc = problem_description[element_index]
    let element_index = element_index + 1
    if(type(desc) != 4 ||  !has_key(desc, "name"))
      continue
    endif

    if(desc["name"] == "p" || desc["name"] == "div") 
      let paragraph = desc["child"]
      let m = len(paragraph)
      let p_el = 0
      let p_sentence = ""
      while p_el < m
        let el = paragraph[p_el]
        let p_el = p_el + 1
        let sentence = ""
        if(type(el) == 1) 
          let sentence = trim(el) 
        elseif(type(el) == 4 && (el["name"] == "span" || el["name"] == "em" || el["name"] == "code") && len(el["child"]) == 1)
          let sentence = " " . trim(el["child"][0]) . " "
        if(el["name"] == "em" && desc["name"] == "div")
          let sentence = "\n" . sentence
        endif
        elseif(type(el) == 4 && el["name"] == "br")
          let sentence = "\n"
        else
          let sentence = " [UNKNOWN WORD] "
        endif
        let p_sentence = p_sentence .  sentence
      endwhile

      let text = text . p_sentence . "\n\n"
    elseif(desc["name"] == "pre" && len(desc["child"]) == 1)
      let code = ""
      if(type(desc["child"][0]) == 1)
        let code = trim(desc["child"][0])
      elseif (type(desc["child"][0]) == 4 && len(desc["child"][0]["child"]) == 1 && desc["child"][0]["name"] == "span")
        let code = trim(desc["child"][0]["child"][0])
      else
        let code = "[UNKNOWN CODE]"
      endif 

      let text = text . "-----------------------\n"
      let text = text . code
      let text = text . "\n-----------------------\n\n"
    elseif(desc["name"] == "ul")
      let bullet_points = desc["child"]
      
      let k = len(bullet_points)
      let p_li = 0
      while p_li < k
        let li = bullet_points[p_li]
        let p_li = p_li + 1
        
        if(type(li) != 4 ||  !has_key(li, "name"))
          continue
        endif

        if(li["name"] != "li")
          text = text . "\t\ŧ * [UNKNOWN ELEMENT]"  
        else  
         " TODO: merge function with p/div 
         

      let paragraph = li["child"]
      let m = len(paragraph)
      let p_el = 0
      let p_sentence = ""
      while p_el < m
        let el = paragraph[p_el]
        let p_el = p_el + 1
        let sentence = ""
        if(type(el) == 1) 
          let sentence = trim(el) 
        elseif(type(el) == 4 && (el["name"] == "span" || el["name"] == "em" || el["name"] == "code") && len(el["child"]) == 1)
          let sentence = " " . trim(el["child"][0]) . " "
        if(el["name"] == "em" && desc["name"] == "div")
          let sentence = "\n" . sentence
        endif
        elseif(type(el) == 4 && el["name"] == "br")
          let sentence = "\n"
        else
          let sentence = " [UNKNOWN WORD] "
        endif
        let p_sentence = p_sentence .  sentence
      endwhile

      let text = text . "\t\t * " . p_sentence . "\n\n" 
        endif
      endwhile
    else 
      let text = text . "[UNKNOWN ELEMENT: ".desc["name"]."]\n\n"
    endif

  endwhile


  return text
endfunction

let s:current_problem_id = ""

function! ui#get_exercise_files()
  call http#fetch_exercise_files(s:current_problem_id)
endfunction

function! s:handle_enter_show_exercise()
  echo "Enter"
endfunction
