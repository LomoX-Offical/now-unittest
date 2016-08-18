#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os,sys
import time
import mimetypes
import smtplib
import subprocess
import psutil

def walk_dir(dir, py_path, topdown = True):
    logpath = os.path.join(os.path.abspath(py_path), "result");
    os.system("mkdir \"%s\"" %(logpath));

    for root, dirs, files in os.walk(dir, topdown):
        for name in files:
            #if name != 'fastcgi_body2.t' : 
            #    continue;
            if name.endswith('.t') == False:
                continue;

            temppath = os.path.join(os.path.abspath(py_path), "temp");
            if os.path.exists(temppath) :
                os.system("rd /S /Q \"%s\"" % (temppath));

            logfile = '%s\\%s.log' % (logpath, name);

            if os.path.exists(logfile) :
                print(name + " skip.");
                continue;

            print(name);

            killed = [];
            for proc in psutil.process_iter():
                if proc.name == 'nginx.exe' and proc.pid != os.getpid():
                    proc.kill();
                    killed.append(proc.pid);
            time.sleep(1);

            cmd_line = 'perl %s' % (os.path.join(name));

            process = subprocess.Popen(args = cmd_line, stderr = subprocess.PIPE, stdout = subprocess.PIPE);
            out, err = process.communicate();

            txt = '----------------------------------------\n';
            txt += 'unit test result:\n';
            txt = '\n---\n';
            txt += '\nname:' + os.path.join(name);
            txt += '\nout:\n' + out;
            txt += '\nerr:\n' + err;


            log = open(logfile, 'w');
            log.write(txt);
            log.close();

        for name in dirs:
            print(os.path.join(root, name));

if __name__ == '__main__' :
    if len(sys.argv) < 1 :
        print "usage : python unitest.py nginx_exe_path";
        sys.exit(0);

    py_path = os.getcwd();
    os.environ['TEST_NGINX_BINARY'] = sys.argv[1];
    os.chdir('.\\nginx-tests');
    walk_dir(os.getcwd(), py_path);

