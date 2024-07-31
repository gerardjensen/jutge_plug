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
  call http#server_available()

  if(!filereadable(s:credentials_file)) 
    echo "Credentials not set, please sign in using :JutgeSetCredentials <email> <password>"
    return 0
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
  call s:system("unzip problem.zip && rm problem.zip")
  
  call s:system("curl -s https://jutge.org/problems/".a:id."/public.tar -b ".s:cookie_file." --output ".a:id."/public_files.tar")
  call s:system("tar xf ".a:id."/public_files.tar -C ".a:id."/")
  call s:system("rm ".a:id."/public_files.tar")
endfunction
