let s:plugindir = expand('<sfile>:p:h:h')
let s:system = function(get(g:, 'webapi#system_function', 'system'))

function! jutge_plug#JutgeSetCredentials(...)
  let l:size = a:0
  if (l:size!=2)
    echo "Only 2 arguments: email and password!"
    return -1
  endif

  let l:email = a:1
  let l:password = a:2

  call writefile([l:email,l:password], s:plugindir.'/credentials.txt','b')
  call http#get_cookie(l:email,l:password)  
endfunction

function! jutge_plug#test_submission(executable_path)
  let l:executable_file = ui#expand_relative_path(a:executable_path)
  let l:input_files = split(globpath(expand('%:p:h'), '*.inp'),"\n")
  let l:output_files = split(globpath(expand('%:p:h'), '*.cor'),"\n")

  if(!filereadable(l:executable_file))
    echo "Can't find file: ".l:executable_file
    return -1
  elseif(!s:valid_input_output_files(l:input_files,l:output_files))
    echo "Invalid test cases"
    return -1
  endif

  let l:i = 0
  let l:n = len(l:input_files)

  let l:log_file_path = ui#expand_relative_path("temp-log.txt")
  if(filereadable(l:log_file_path))
    echo "Note: found file with name " . l:log_file_path . " which was the output test file, please delete or rename that file to perform this test"
    return -1
  endif

  while(l:i < l:n)
    let l:input = l:input_files[l:i]
    let l:output = l:output_files[l:i]
    let l:output_name = fnamemodify(l:output, ":t:r")
    let l:test_command = l:executable_file . " < " . l:input ." > " . l:log_file_path
    call s:system(l:test_command)
    let l:diff_command = "diff -q " . l:log_file_path . " " . l:output
    let l:result = s:system(l:diff_command)
    
    if(empty(l:result))
      echo "Test " . l:output_name . ": [OK]" 
    else
      echo "Test " . l:output_name . ": [NOK]" 
    endif

    let l:i = l:i + 1
  endwhile
  call s:system("rm " . l:log_file_path)
endfunction

function! s:valid_input_output_files(input_files,output_files)
  if(len(a:input_files) != len(a:output_files) || len(a:input_files) == 0)
    return 0
  endif

  let l:i = 0
  let l:n = len(a:input_files)
  while (l:i < l:n)
    let l:input_name = fnamemodify(a:input_files[l:i],":t:r")
    let l:output_name = fnamemodify(a:output_files[l:i],":t:r")
    if(l:input_name != l:output_name)
      return 0
    endif
    let l:i = l:i + 1
  endwhile
  return 1
endfunction
