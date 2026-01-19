# CF_Dumpvar
### A better CFDump.

This custom tag came into being after I got tired of viewing a query output via cfdump and having the columns in alphabetical order in all upper case. The original version
was written in CF tag syntax and I decided to write a new version in cfscript to get better used to writing in cfscript. This does have the side effect of removing engines
that do not support cfscript used in CF2025 that I wrote this code in, then made backward compatible with older version and Lucee where I could.

I also added additional functionality to what cfdump returns as shown below. Note that running in Lucee will return a dump formatted as if it came from ColdFusion - I will
add Lucee styling at some point.

The syntax is the same as ``CFDump`` with the exception that output="console" is not supported.

## ColdFusion Engines Supported
- [ ] ColdFusion 10
- [ ] ColdFusion 11
- [ ] ColdFusion 2016
- [x] ColdFusion 2018
- [x] ColdFusion 2021
- [x] ColdFusion 2023
- [x] ColdFusion 2025
- [x] Lucee 4
- [x] Lucee 5
- [x] Lucee 6
- [ ] Railo 4
- [ ] BlueDragon

### Call as a Custom Tag
```
<CF_Dumpvar var=#PNG#>
```

### Call as a function
```
<cfscript>
include "dumpvar.cfm" runonce=true;
PNG=imageRead("D:\CFLogo.png");
Dumpvar(var=#PNG#);
</cfscript>
```

> [!IMPORTANT]
> I decided to write this function in cfscript to get more used to the script based version of ColdFusion but that turned out to have side effects in that I am unable to trap or exclude code from excluding packages that are not installed. You will need to install the following packages in order to run the function or comment out the relevent block. You can search for "handle pdf" for the PDF logic for example.\
> Run the following to install the required packages: `cfpm install pdf sqlserver spreadsheet`

## Structs

> [!CAUTION]
> ColdFusion's `<CFDump>` tag has an error in how it handles case sensitive structs in that if you have the same string of text as a key name in different case such as "A" and "a", you can't filter on the lower case version. See [Bug Tracker CF-4229243](https://tracker.adobe.com/#/view/CF-4229243) (Lucee 6 also seems to handle this case output incorrectly.)

Example of the bug
```
<cfset struct=structNew("casesensitive")>
<CFSET Struct.A="A">
<CFSET Struct.a="a">
<CFSET Struct.B="B">
<CFSET Struct.b="b">
<CFSET Struct.C="C">
<CFSET Struct.c="c">
<cfdump var=#struct#>
<cfdump var=#struct# show="b">
<cfdump var=#struct# hide="b">
```
<img width="210" height="258" alt="image" src="https://github.com/user-attachments/assets/d3fb3db2-c076-48c4-955b-0d3341e32dee" />\
The code states to either show or hide the lower case "b" version. It either displays the upper case value with the lower case values or displays the upper case version of the lower case name.

`<CF_Dumpvar>` supports both case insensitive matching and case sensitive.\
```
<cf_dumpvar var=#struct# Show="b">
```
<img width="273" height="67" alt="image" src="https://github.com/user-attachments/assets/fb72afb0-24a0-49a0-b1f7-038cc8587d91" />

```
<cf_dumpvar var=#struct# Show="b" HonorCase=true>
```
<img width="355" height="48" alt="image" src="https://github.com/user-attachments/assets/0a4f1488-c5cb-4345-9175-5ddcaef64b19" />


## Arrays

`CFDump` does not indicate if an array was created as a "fast array" which is not thread safe.\
Left side is from `CFDump`, the right from `CF_Dumpvar`
```
<CFSET Arr=ArrayNew(1,false)>
<CFSET Arr[1]="Foo">
<CFSET Arr[2]="Bar">
```

<img width="136" height="72" alt="image" src="https://github.com/user-attachments/assets/435a5be8-c000-48cf-849b-ff0a42c4c142" />

## Binary
Viewing a binary variable with ``CFDump`` has always been useless since it displays it as a bytearray numeric values from -127 to 128 and without spaces in between values. Any value less than zero needs to have 256 added to it to get the true value.\
`CF_Dumpvar` displays the binary data like it was viewed by a hex editor, the HEX code is displayed on the left side with the ASCII value displayed on the right.

Here are two binary variable dumps using ``CFDump`` and ``CF_Dumpvar``. The first pair is from a Windows text file, the second pair a PNG image.

<img width="1106" height="556" alt="image" src="https://github.com/user-attachments/assets/75b73515-755e-4f04-8fcb-3ff7c7139ce7" />

## Images
``CF_Dumpvar`` displays the same struct info as ``CFDump`` but includes a view of the image, resized to 250px if larger on height or width. Lucee does display the image above the struct but full sized.\
<img width="553" height="398" alt="image" src="https://github.com/user-attachments/assets/ada12a48-06cf-4b51-804e-6cbee1e42611" />

## PDF
> [!CAUTION]
> Be mindful of working on PDF objects, the "PageRotations" & "PageSizes" array is a "fast array" which is not thread safe. On a multi-user site that maniplates PDF documents to wrap it in a named exclusive cflock to prevent against race conditions.

> [!NOTE]
> Thumbnail generation not supported with Lucee

Thumbnails of the PDFDocument are generated and displayed to the right of the PDF information output.\
The left side is the output of `CFDump`, the right from `CF_Dumpvar`.\
The source PDF comes from https://www.adobe.com/cc-shared/assets/pdf/products/coldfusion-family/support-matrix-2025.pdf
<img width="995" height="1144" alt="image" src="https://github.com/user-attachments/assets/7f57e790-a08c-4783-b52e-fac3d94a5d73" />

## Queries
The top result is generated by ``CFDump`` and the bottom by ``CF_Dumpvar``\
<img width="491" height="531" alt="image" src="https://github.com/user-attachments/assets/a1ef2603-7611-49ba-a445-e97815d197e1" />

> [!NOTE]
> `<CF_Dumpvar` on Lucee does not display the query metadata at this time.

## Spreadsheets
> [!NOTE]
> Spreadsheet full output is currently supported with ColdFusion 2025 (and newer)

I was upgrading the 7 year old hard drives in my NAS and I created a spreadsheet to try to figure out which drives to get and get my best bang for my bucks. I used that spreadsheet on this demo.\
HTML generation is done with pure HTML/CSS/Javascript and sheet tabs are functional.\
The "Sheets" value is updated from a simple number of sheets to more detailed information on the sheets. Sheet names that contain commas are properly handled.\
<img width="509" height="889" alt="image" src="https://github.com/user-attachments/assets/1e6c5731-8525-4f28-95b1-2924a20c896b" />\
<img width="1256" height="671" alt="image" src="https://github.com/user-attachments/assets/21964efd-4cc2-4b85-9f49-f53e2d7666b8" />

> [!NOTE]
> To Do: Extract cell formatting, formulas, cell spanning, comments, and notes and render the HTML utilizing that info
