let s:system = function(get(g:, 'webapi#system_function', 'system'))

let s:plugindir = expand('<sfile>:p:h:h')
let s:cookie_file = s:plugindir."/cookies.txt"
let s:mode = 0  " 0 -> Listing courses
                " 1 -> Showing exercise

function! ui#JutgeShowProblems()
  let s:courses = ui#fetch_problems()

  let disp_text = ui#make_course_text()
  call s:create_window()
  call s:add_mappings()
  call s:set_init_text(disp_text) 

  "let json_string = webapi#json#encode(obj)
  "call writefile(split(json_string,"\n",1), s:plugindir.'/obj.txt','b')
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

function! ui#make_course_text() 
  let disp_text = "Enrolled courses:\n\n"
  
  let index = 0
  let courses_len = len(s:courses)
  while(index < courses_len)
    let course = s:courses[index]
    let disp_text = disp_text."\t * ".course["name"]."\n"

    if(course["lessons_visible"])
      let lessons_len = len(course["lessons"])
      let lindex = 0
      while(lindex < lessons_len)
        let lesson = course["lessons"][lindex]
        let disp_text = disp_text."\t\t\t > ".lesson["name"]."\n"
        
        if(lesson["exercices_visible"])
          let exercices_len = len(lesson["exercices"])
          let eindex = 0
          while(eindex<exercices_len)
            let exercice = lesson["exercices"][eindex]

            let disp_text = disp_text."\t\t\t\t\t ".exercice["status"]." ".exercice["name"]."\n"
            let eindex += 1
          endwhile
        endif

        let lindex+=1
      endwhile
    endif

    let disp_text = disp_text."\n"
    let index += 1
  endwhile
  return disp_text
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
          let exercice_status = "✔️"
        elseif (stridx(status_box_style,"red") != -1)
          let exercice_status = "✗" 
        else
          let exercice_status = "⚖️"
        endif
      endif
      let exercice_id = exercice_content[3]["child"][0]
      let exercice_id = trim(exercice_id)
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

function! ui#replace_accents(text)
  let text = substitute(a:text,"&aacute;","á","g")
  let text = substitute(text,"&eacute;","é","g")
  let text = substitute(text,"&iacute;","í","g")
  let text = substitute(text,"&oacute;","ó","g")
  let text = substitute(text,"&uacute;","ú","g")
  let text = substitute(text,"&agrave;","à","g")
  let text = substitute(text,"&egrave;","è","g")
  let text = substitute(text,"&ograve;","ò","g")
  return text
endfunction

function! s:create_window()
  vertical botrigh 60new                            " create a new window on the right that's 80 columns wide
  setlocal nomodifiable                             " stop the user from editing the buffer
  setlocal buftype=nofile bufhidden=wipe noswapfile " tell Vim this is a temporary buffer not backed by a file
  setlocal nonumber cursorline wrap nospell         " no line numbers, wrapping, highlight the current line
  file Jutge Problems                                     " set the file name of the buffer
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
  let c_line = 3
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

  " echo course_index . ", " . lesson_index . ", " . exercice_index

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
  let id = a:id

  echo "Fetching problem: ".id
  
  let res = ui#fetch_html_with_cookie("https://jutge.org/problems/".id."/")
endfunction

function! s:handle_enter_show_exercise()
  echo "Enter"
endfunction
