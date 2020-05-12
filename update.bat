@echo off
title EasyChat Update
set /p changes="Changes: "
set location=./
set id=1182471500

git commit -a -m "%changes%"
git push

if exist "%location%" (
	gmad.exe create -folder "%location%" -out "%location%.gma"
	if exist "%location%.gma" (
		gmpublish.exe update -addon "%location%.gma" -id "%id%" -changes "%changes%"
	) else (
		echo Could not create gma archive, aborting
	)
) else (
	echo Could not find the specified path
)

if exist "%location%.gma" (
	del /Q "%location.gma"
)

pause