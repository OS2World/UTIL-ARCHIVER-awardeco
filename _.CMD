@echo off

call stampdef awardeco.def

call pasvp awar_def %tmp%\ @awardeco.cfg
%tmp%\awar_def.exe
del %tmp%\awar_def.exe

call pasvpdsp awardeco awardeco.vk\ @awardeco.cfg
copy awardeco.vk\awardeco.exe awardeco.vk\awardeco.com
call copywdx awardeco.vk\

call pasvp awardeco awardeco.vk\ @awardeco.cfg
call ..\genvk AwarDeco

cd awardeco.vk
call genpgp
cd ..