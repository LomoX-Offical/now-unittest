#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os,sys
import time
import mimetypes
import smtplib
import subprocess
import psutil

def walk_dir(dir,fileinfo,topdown=True):
    for root, dirs, files in os.walk(dir, topdown):
        for name in files:
            if name.endswith('.t'):
                print(os.path.join(name))
                logpath = os.path.dirname(os.path.abspath(sys.argv[0]))
                
                killed = []
                for proc in psutil.process_iter():
                    if proc.name == 'nginx.exe' and proc.pid != os.getpid():
                        proc.kill()
                        killed.append(proc.pid)
                time.sleep(5)
                
                os.system('perl %s > %s\\1.log'%(os.path.join(name),logpath))                
                f=open('%s\\1.log'%logpath,'r+')
                ftxt=os.path.join(name) + '\n' + f.read()
                cmd_line = 'perl %s'%os.path.join(name)
                process = subprocess.Popen(args=cmd_line, stderr=subprocess.PIPE)
##                print process.stderr.read();          
                htmlText = process.stderr.read();
                ftxt += htmlText
                log= open('%s\\nginx.log'%logpath,'a')
                log.write(ftxt)
        for name in dirs:
##            print(os.path.join(name))
            fileinfo.write('  ' + os.path.join(root,name) + '\n')
    f.close()
    ftxt1='----------------------------------------'
    ftxt2='来自Auto_Test_Ent机器人助手NginxTest的消息'
    ftxt1=ftxt1+'\n'+ftxt2
    log.write(ftxt1)
    log.close()
if __name__ == '__main__' :
    os.chdir('.\\unit-tests')
    fileinfo = open('..\\list2.txt','w')
    walk_dir(os.getcwd(),fileinfo)
    fileinfo.close()

 
