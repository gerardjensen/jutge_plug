let s:mode = 0
" 0 -> Listing courses
" 1 -> Showing exercise

let g:VERSION = "0.1"
let g:CORRECT_EXERCISE_CHECK = "✔️"
let g:INCORRECT_EXERCISE_CHECK = "✗"
let g:PARTIAL_EXERCISE_CHECK = "⚖️"

let s:match_ids = []
let s:course_lines = [] " Lines where the title of a course is

highlight GreenText ctermfg=Green guifg=Green
highlight RedText ctermfg=Red guifg=Red
highlight YellowText ctermfg=Yellow guifg=Yellow
  
highlight TitleText ctermfg=Blue guifg=Blue ctermbg=NONE guibg=NONE
highlight CourseText ctermfg=DarkGreen guifg=DarkGreen ctermbg=NONE guibg=NONE

function! ui#JutgeShowProblems()
  if(bufwinid('Jutge Problems') != -1)
    echo "JutgePlug is already running"
    return
  endif

  let s:mode = 0
  let s:courses = http#fetch_problems()

  call s:create_window()
  
  nmap <silent> <buffer> q :bd<CR>
  nmap <silent> <buffer> <Enter> :call <SID>handle_enter()<CR> 

  nmap <silent> <buffer> d :call ui#get_exercise_files()<CR>
  nmap <silent> <buffer> b :call ui#go_back_to_courses()<CR>
   
  setlocal modifiable
  let l:disp_text = ui#make_course_text()
  let l:lines = split(l:disp_text, '\n')
  call append(0, l:lines)
  setlocal nomodifiable
endfunction

function! s:create_window()
  vertical botrigh 90new                            " create a new window on the right that's 60 columns wide

  setlocal nomodifiable                             " stop the user from editing the buffer
  setlocal buftype=nofile bufhidden=wipe noswapfile " tell Vim this is a temporary buffer not backed by a file
  setlocal nonumber cursorline wrap nospell         " no line numbers, wrapping, highlight the current line

  call s:highlight_statics()

  file Jutge Problems                               " set the file name of the buffer
endfunction

function! s:highlight_statics()
  call matchadd('GreenText', g:CORRECT_EXERCISE_CHECK)
  call matchadd('RedText', g:INCORRECT_EXERCISE_CHECK)
  call matchadd('YellowText', g:PARTIAL_EXERCISE_CHECK)

  call matchaddpos('TitleText',[1])
endfunction

function! ui#make_course_text() 
  let l:disp_text = "JUTGE VIM PLUGIN v".g:VERSION."\n\nEnrolled courses:\n\n"
  let s:course_lines = map(range(len(s:courses)), 0)
  let l:index = 0
  let l:courses_len = len(s:courses)
  let l:current_line = 5 " 5 is the first line where a course title is placed
  let l:courses_added = 0
  while(l:index < l:courses_len)
    let l:course = s:courses[l:index]
    let l:disp_text = l:disp_text."\t * ".l:course["name"]."\n"
    let s:course_lines[l:courses_added] = l:current_line
    let l:courses_added = l:courses_added + 1
    let l:current_line = l:current_line + 1

    if(l:course["lessons_visible"])
      let l:lessons_len = len(l:course["lessons"])
      let l:lindex = 0
      while(l:lindex < l:lessons_len)
        let l:lesson = l:course["lessons"][l:lindex]
        let l:disp_text = l:disp_text."\t\t\t > ".l:lesson["name"]."\n"
        let l:current_line = l:current_line + 1

        if(l:lesson["exercices_visible"])
          let l:exercices_len = len(l:lesson["exercices"])
          let l:eindex = 0
          while(l:eindex < l:exercices_len)
            let l:exercice = l:lesson["exercices"][l:eindex]

            let l:disp_text = l:disp_text."\t\t\t\t\t ".l:exercice["status"]." ".l:exercice["name"]."\n"
            let l:current_line = l:current_line + 1
            let l:eindex += 1
          endwhile
        endif

        let l:lindex+=1
      endwhile
    endif

    let l:disp_text = l:disp_text."\n"
    let l:current_line = l:current_line + 1
    let l:index += 1
  endwhile

  call s:reset_highlighting()  
  return l:disp_text
endfunction

function! s:reset_highlighting()
  call s:clear_highlights()

  for line in s:course_lines
    call add(s:match_ids, matchaddpos('CourseText', [[line]]))
  endfor

  call s:highlight_statics()
endfunction

function! s:clear_highlights()
  for id in s:match_ids
    call matchdelete(id)
  endfor
  let s:match_ids = []
endfunction

function! s:handle_enter_list_courses()
  setlocal modifiable
  let l:line_enter = line('.')
  let l:column_enter = col('.')

  silent! normal! gg"_dG

  let l:res = s:update_courses_vis(l:line_enter)
  if(l:res == -1)
    let l:disp_text = ui#make_course_text()

    let l:lines = split(l:disp_text, '\n')
    call append(0, l:lines)

    call cursor(l:line_enter, l:column_enter)
  else
    call ui#show_problem(l:res)
  endif

  setlocal nomodifiable
endfunction

function! s:handle_enter()
  if(s:mode == 0)
    call s:handle_enter_list_courses()
  endif
endfunction

function! s:update_courses_vis(line)
  let l:c_line = 5
  if (a:line < l:c_line)
    return -1
  endif
  let l:course_index = 0
  let l:lesson_index = -1
  let l:exercice_index = -1

  let l:courses_len = len(s:courses)

  while (l:c_line < a:line)
    let l:course = s:courses[l:course_index]
    let l:course_vis_lines = ui#get_course_vis_lines(l:course)

    if (a:line > l:c_line + l:course_vis_lines)
      let l:c_line += l:course_vis_lines + 1
      let l:course_index += 1

      if (l:course_index >= l:courses_len)
        return -1
      endif 
    else
      if (l:lesson_index + 1 >= len(l:course["lessons"]))
        return -1
      endif
      let l:lesson = l:course["lessons"][l:lesson_index+1]
      let l:lesson_vis_lines = ui#get_lesson_vis_lines(l:lesson)

      if (l:c_line + l:lesson_vis_lines < a:line)
        let l:c_line += l:lesson_vis_lines
        let l:lesson_index += 1

        if (l:lesson_index >= len(l:course["lessons"]))
          return -1
        endif
      else
        if (l:c_line + 1 == a:line)
          let l:lesson_index += 1
          break
        endif
        let l:lesson_index += 1

        let l:exercice_index += a:line - l:c_line - 1
        break
      endif
    endif
  endwhile

  if (l:lesson_index == -1)
    let s:courses[l:course_index]["lessons_visible"] = !s:courses[l:course_index]["lessons_visible"]
  elseif (l:exercice_index == -1)
    if (s:courses[l:course_index]["lessons_visible"] && l:lesson_index < len(s:courses[l:course_index]["lessons"]))
      let s:courses[l:course_index]["lessons"][l:lesson_index]["exercices_visible"] = !s:courses[l:course_index]["lessons"][l:lesson_index]["exercices_visible"]
    endif
  else
    return s:courses[l:course_index]["lessons"][l:lesson_index]["exercices"][l:exercice_index]["id"]
  endif

  return -1
endfunction

function! ui#get_course_vis_lines(course)
  if(!a:course["lessons_visible"])
    return 1
  endif

  let l:lessons = a:course["lessons"]
  let l:lessons_line_sum = 0
  let l:lessons_cnt = len(l:lessons)

  let l:lindex = 0
  while(l:lindex < l:lessons_cnt)
    let l:lesson = l:lessons[l:lindex]
    let l:lessons_line_sum += ui#get_lesson_vis_lines(l:lesson)

    let l:lindex+=1
  endwhile

  return 1 + l:lessons_line_sum
endfunction

function! ui#get_lesson_vis_lines(lesson)
  if(!a:lesson["exercices_visible"])
    return 1
  endif

  let l:exercices = a:lesson["exercices"]
  let l:exercices_cnt = len(l:exercices) 
  return 1 + l:exercices_cnt
endfunction

function! ui#show_problem(id)
  let s:mode = 1
  let l:disp_text = ui#fetch_exercise_mk_text(a:id)

  call s:clear_highlights()
  let l:lines = split(l:disp_text, '\n')
  call append(0, l:lines)
  call cursor(1,0)
endfunction

function! ui#fetch_exercise_mk_text(id)
  let s:current_problem_id = a:id
  let l:obj = http#fetch_html_with_cookie("https://jutge.org/problems/".a:id."/")

  let l:body = l:obj["child"][1]["child"][17]
  let l:content = l:body["child"][3]["child"][1]
  let l:title = l:content["child"][5]["child"][1]["child"][2]
  let l:title = trim(l:title)

  let l:text = "> ".l:title."\n\n"
  
  let l:problem_status = l:content["child"][9]["child"][1]["child"][1]["child"][1]["child"][1]["child"][0]
  let l:problem_status = trim(l:problem_status)
  let l:text = l:text . l:problem_status."\n\n"

  try 
    let l:problem_description = l:content["child"][9]["child"][3]["child"][3]["child"][3]["child"][3]["child"][3]
    let l:text = l:text . s:html_dom2text(l:problem_description)
  catch
    " Some content is located in a different structure in the HTML, probably
    " some legacy stuff
   try 
      let l:problem_description = content["child"][9]["child"][3]["child"][3]["child"][3]["child"][5]["child"][1]["child"][3] 
      let l:text = l:text . s:html_dom2text(l:problem_description)
    catch
      let l:text = l:text . "There was a problem viewing this exercise (probably the UI changed). Please read from the pdf"
    endtry
  endtry
  
  return l:text
endfunction

let s:current_problem_id = ""
let s:t_string = 1
let s:t_dict = 4

function! s:html_dom2text(obj)
  return s:html_dom2text_aux("html",a:obj,0)
endfunction

let s:last_element_tag = ""
let s:first_in_div = 0
let s:first_paragraph = 0

function! s:html_dom2text_aux(father_tag, obj,inside_pre)
  if(type(a:obj) == s:t_string) 
    if(trim(a:obj) == "")
      return "" " This prevents the display of line breaks of blocs (not content) in the html file
                " because the webapi still detects those
    else
      if(a:father_tag == "div:lstlisting")
        let s:last_element_tag = ""
      endif
      
      if(!a:inside_pre && a:father_tag != "div:lstlisting")
        return s:remove_linebreaks(a:obj)
      else
        return a:obj
      endif
    endif
  endif

  if(type(a:obj) != s:t_dict || !has_key(a:obj, "child")|| !has_key(a:obj, "name")) 
    return "[INVALID TEXT]"
  endif

  let l:children = a:obj["child"]

  let l:tag_type = tolower(trim(a:obj["name"]))

  if(l:tag_type == "div" && s:is_of_class(a:obj,"lstlisting"))
    let l:tag_type = "div:lstlisting"
    let s:first_in_div = 1
  endif
  
  let l:inside_pre = a:inside_pre
  let l:ret_str = ""
  if(l:tag_type == "li")
    let l:ret_str = "\n\t\t * "
  elseif(l:tag_type == "br" || l:tag_type == "p" && a:father_tag == "li")
    let l:ret_str = "\n"
  elseif(l:tag_type == "pre")
    let l:ret_str = "--------------------------------\n"
    let l:inside_pre = 1
  endif

  let l:i = 0
  let l:n = len(l:children)
  
  while l:i < l:n
    let l:el = l:children[l:i]
    let l:i = l:i + 1

    if(a:father_tag == "div:lstlisting" && l:tag_type == "em")
      let l:ret_str = l:ret_str . "\n"
    endif
    
    if(a:father_tag == "div:lstlisting")
      if(l:tag_type == "span" && (s:last_element_tag == l:tag_type || s:first_in_div)) " TODO: em's can also have a space before in some conditions
        let l:ret_str = l:ret_str . " "
        let s:first_in_div = 0
      endif

      let s:last_element_tag = l:tag_type
    endif
    let l:text_append = s:html_dom2text_aux(l:tag_type, l:el,l:inside_pre)
    
    if(s:get_last_char(l:ret_str) == '\n' && s:get_first_char(l:ret_str) == "\n")
      let l:ret_str = s:remove_last_char(l:ret_str)
    endif
    let l:ret_str = l:ret_str . l:text_append
  endwhile

  if(l:tag_type == "p" || l:tag_type == "ul" || l:tag_type == "div:lstlisting" || l:tag_type == "table")
    let l:ret_str = l:ret_str . "\n\n"
  elseif(l:tag_type == "sub")
    let l:ret_str = "_{" . l:ret_str . "}"
  elseif(l:tag_type == "pre")
    let l:ret_str = l:ret_str. "\n--------------------------------\n\n"
  endif  
  return l:ret_str
endfunction

function! s:remove_linebreaks(str)
    let l:result = substitute(a:str, '\n', ' ', 'g')
    let l:result = substitute(l:result, '\r', ' ', 'g')
    return l:result
endfunction

function! s:remove_last_char(str)
    let l:len = len(a:str) 
    let l:result = strpart(a:str, 0, l:len - 1)
    return l:result
endfunction

function! s:get_first_char(str)
    if len(a:str) == 0
        return ''
    endif
    let l:first_char = strcharpart(a:str, 0, 1)
    return l:first_char
endfunction

function! s:get_last_char(str)
  let l:len = len(a:str)
  if l:len == 0
    return ''
  endif
  let l:last_char = strcharpart(a:str, l:len - 1, 1)
  return l:last_char
endfunction

function! s:is_of_class(obj, class)
  return has_key(a:obj,"attr") && has_key(a:obj["attr"],"class") && a:obj["attr"]["class"] == a:class
endfunction

function! ui#get_exercise_files()
  if(s:mode != 1) 
    call "No exercise selected"
    return -1
  endif
  call http#fetch_exercise_files(s:current_problem_id)
endfunction

function! ui#upload_submission(...)
  let l:size = a:0
  if(l:size != 2) 
    echo "JutgePlug: Invalid usage of JutgeUpload. Correct is JutgeUpload <file> <compiler>"
    return -1
  endif

  if(s:mode != 1) 
    echo "No exercise selected"
    return -1
  endif

  let l:filepath = ui#expand_relative_path(a:1)
  let l:compiler = a:2 " TODO: Check for invalid compiler (requires updating or making a new JS script)

  if(!filereadable(l:filepath))
    echo "Invalid path: ".l:filepath
    return -1
  endif

  call http#send_submission(s:current_problem_id,l:filepath, l:compiler)
endfunction

function! ui#expand_relative_path(file_path)
  if a:file_path =~ '^/'
      let l:expanded_path = a:file_path
  else
      let l:current_dir = expand('%:p:h')
      let l:expanded_path = l:current_dir . '/' . a:file_path
  endif
  let l:normalized_path = fnamemodify(l:expanded_path, ':p')

  return l:normalized_path
endfunction

function! ui#go_back_to_courses()
  setlocal modifiable
  silent! normal! gg"_dG
  
  let s:mode = 0
  let s:courses = http#fetch_problems()
  
  let l:disp_text = ui#make_course_text()
  let l:lines = split(l:disp_text, '\n')
  call append(0, l:lines)
  setlocal nomodifiable
endfunction
