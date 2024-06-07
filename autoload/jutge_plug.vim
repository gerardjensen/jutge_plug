let s:plugindir = expand('<sfile>:p:h:h')

function! jutge_plug#JutgeSetCredentials(...)
  let size = a:0
  if (size!=2)
    echo "Only 2 arguments: email and password!"
    return -1
  endif

  let email = a:1
  let password = a:2

  call writefile([email,password], s:plugindir.'/credentials.txt','b')
  call http#get_cookie(email,password)  
endfunction
