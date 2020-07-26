@echo off
title EasyChat Update
set /p changes="Changes: "

git add *
git commit -a -m "%changes%"
git push

gmad.exe create -folder "./" -out ".gma"
if exist ".gma" (
	gmpublish.exe update -addon ".gma" -id "1182471500" -changes "%changes%"
) else (
	echo Could not create gma archive, aborting
)

if exist ".gma" (
	del /Q ".gma"
)

pause