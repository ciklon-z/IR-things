# Copyright
# =========
# Copyright (C) 2012 Trustwave Holdings, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>
#
#
# advnetcfg_string_deobfuscate.py by Josh Grunzweig 5-31-2012
#
# =Synopsis
#
# This is an idapython script designed to deobfuscate strings in the 
# advnetcfg.ocx malware sample (bb5441af1e1741fca600e9c433cb1550). In this 
# particular sample, the decrypt function was identified at 0x1000BE16, which
# is set accordingly below. If it is discovered that the decrypt function has
# been changed to a different location, please update the base_value variable
# below to the appropriate value. 
#
# An example of the decrypt function being called can be seen below:
#
# .text:10003A0F                 push    edi
# .text:10003A10                 mov     [ebp+var_10], esp
# .text:10003A13                 and     [ebp+var_4], 0
# .text:10003A17                 push    offset unk_1008FBB8
# .text:10003A1C                 call    sub_1000BE16
# .text:10003A21                 pop     ecx
# .text:10003A22                 push    eax             ; Src
# .text:10003A23                 lea     eax, [ebp+var_1C]
#
# In the above example, unk_1008FBB8 is set to the following:
#
# 90 11 80 5C B6 F8 26 DA  D1 3E C7 2C D4 87 D5 0B
# C0 E3 30 00 A7 A2 23 E8  62 37 BA 8D 0E EB 72 52
# C9 BC 47 37 B5 B1 40 3C  CC C2 3A 59 1A FF AF A6
# 62 49 1D 0C CF CA 99 81  1A 5C FC 27 BF 06 D4 FC
# D7 D3 C2 DA 00 00 9B 3C  E4 89 5C 43 40 DE 53 5F
# 7D 7F 29 BE DD 8B 00 00  00 00 00 00 00 00 00 00
# 
# 
# This script will automatically discover all XREFs to the deobfuscate function,
# and will then proceed to comment each unk that is supplied to that function.
# 
# In addition, a number of debugging message will be displayed, to provide the
# user with both the location of the unk, as well as the decoded string.
#

import sys
import binascii
import re

base_value = 0x1000BE16

def decrypt(num):
    val = ((num+5) * (num+26) ^ (((num+5) * (num+26) >> 8) ^ (((num+5) * (num+26) ^ (((num+5) * (num+26)) >> 8)) >> 16)))
    return ("%2X" % val)[-2:]

def initial_decrypt(string):
    string = binascii.unhexlify(string)
    return_list = []
    if string[16] != "\x00":
        count = 0
        for value in str(string[20:]):
            dec_value = int(decrypt(count),16)
            value_to_set = (int(binascii.hexlify(value),16) - dec_value)
            if value_to_set < 0:
                dec_value = ((dec_value ^ 255)+1)*-1
                value_to_set = (int(binascii.hexlify(value),16) - dec_value)
            if value_to_set != 0:
                return_list.append(chr(value_to_set))
            count+=1
    return ''.join(return_list)


for ref in CodeRefsTo(base_value, 1):
    new_ref = Dword(int(ref)-4)
    bool_var = Byte(new_ref+16)
    size = Byte(new_ref+18)+20
    manybytes = GetManyBytes(new_ref, (size))
    decoded_string = initial_decrypt(binascii.hexlify(manybytes))
    idc.MakeRptCmt(new_ref, decoded_string)
    idc.MakeName(new_ref, (re.sub('[\W_]', '_', decoded_string)+"_"+hex(new_ref)))
    print("[+] Adding comment "+str(hex(new_ref))+" : \""+decoded_string+"\"")
    


