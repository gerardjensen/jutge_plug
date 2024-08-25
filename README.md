# Jutge Plugin
A plugin to interface with jutge.org within Vim.

## Installation
If you use [vim-plug](https://github.com/junegunn/vim-plug) :

```vim
Plug 'https://github.com/gerardjensen/jutge_plug'
```

in your `.vimrc` or `init.vim` and run `:PlugInstall`.

### Dependencies

JutgePlug depends on the following programs under the hood:
  * `curl`
  * `unzip`
  * `rm`
  * `tar`
  * `diff`
  * `node` with `puppeteer` and its `chrome` browser (only used to upload the submission, if you won't do that then it is not necessary)

## Usage
There are 6 vim commands to use

### Setting the credentials
To be able to log in, use the command `JutgeSetCredentials` as follows

    :JutgeSetCredentials <email> <password>

Note, that your password is stored in a txt file in the plugin folder. Please keep in mind it is not encrypted since the plugin has to send it as is to the jutge server to log in. I am not responsible for any potential password leak.

### Checking the cookie status
You can use `:JutgeCheckCookieValidity` to see if the current cookie is valid and if not, it tries to renew it. The cookie is automatically updated when initialising vim so you should never need to use this command.

### Navigating through the problems
Use `:JutgeShowProblems` to open a window with your enrolled courses. Put the cursor on a line where the course title is and press `Enter` to see the topics. Press it again to see the problems.
Pressing on a problem loads the exercise statement (as viewed on the web). You can press `b` to go back to the problem list

### Downloading an exercise
When navigated to the problem you want to try, press `d`, or use the `:JutgeGetExerciseFiles` command to download the exercises. It will be extracted in the folder where you started vim, inside a folder of the ID.
Note, that all files will be overwritten, so be careful.

### Testing and uploading
To test an executable, after manually compiling the code, use the `:JutgeTest <executable>`. It will look at the `.inp/.cor` files in the same folder and use them to make the test (which are automatically downloaded with the rest of the problem files).

To upload, use:

    :JutgeUpload <file> <compiler>

Where `<compiler>` is one of the available compilers (the ones in the dropdown list, note, it has to correspond to one there). For example, for a C++ code, it would be:

    :JutgeUpload main.cc P1++

A local test is not automatically performed before an upload

# Final notes
This plugin has only been tested in Debian 12 with neovim 9. The dependencies and commands are thus, used as in Linux, so it may not work on other platforms.
I haven't protected the whole plugin from an incorrect use. Do not try to navigate to the problems without having logged in, for example, as some errors may pop up.

I am sad I couldn't use `curl` for all the networking stuff. I was forced to use `node` because even though a request can be made with `curl`, jutge uses some javascript to handle the requests and I am no wizard.

## Stability
This plugin is not official, it is a literal web scrapping plugin and if the UI of jutge changed, the plugin would stop working. As of now, there is not a consistent HTML structure in the exercise pages, this means that all the tested exercises are supported but it is not guaranteed that it works in all of them. 

Please feel free to add any issues or contact me.

Happy coding!
