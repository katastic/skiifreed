#!/bin/sh

#of  output file
#ldc2 -w -release -ofmain main.d -L-L. $@    -gc -d-debug=3  -de

ldc2 -w -release -ofmain main.d -L-L. $@

# globals.d 

#-release
# -gc optmize for non-D debuggers
# -O3 max debug (may allow others later)

#  -march=<string>                   - Architecture to generate code for:
#  -mattr=<a1,+a2,-a3,...>           - Target specific attributes (-mattr=help for details)
#  -mcpu=<cpu-name>                  - Target a specific cpu type (-mcpu=help for details)


# TRY THESE
#
# ldc2 -mattr=help
# ldc2 -mcpu=help 


# Talk on supported versions:
# http://llvm.org/devmtg/2014-04/PDFs/LightningTalks/2014-3-31_ClangTargetSupport_LighteningTalk.pdf


# -de  show use of deprecated features as errors (halt compilation) 
#https://wiki.dlang.org/Using_LDC
