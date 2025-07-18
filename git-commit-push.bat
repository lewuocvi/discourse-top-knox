
@echo off
:: Add all changes to the staging area
git add *

:: Commit changes with a message
git commit -m "add"

:: Push changes to the main branch
git push origin main

:: Wait for 5 seconds before exiting
timeout /t 5 > nul