# CF_DumpVar
A better CFDump.

The syntax is the same as ``CFDump`` with the exception that output="console" is not suppported.

### Call as a Custom Tag
```
<CF_Dumpvar var=#PNG#>
```

### Call as a function
```
<cfscript>
include "dumpvar.cfm" runonce=true;
PNG=imageRead("D:\CFLogo.png");
Dump(var=#PNG#);
</cfscript>
```

## Arrays

`CFDump` does not indicate if an array was created as a "fast array" which is not threadsafe.\
Left side is from `CFDump`, the right from `CF_DumpVar`
```
<CFSET Arr=ArrayNew(1,false)>
<CFSET Arr[1]="Foo">
<CFSET Arr[2]="Bar">
```

<img width="136" height="72" alt="image" src="https://github.com/user-attachments/assets/435a5be8-c000-48cf-849b-ff0a42c4c142" />

## Binary
Viewing a binary variable with ``CFDump`` has always been useless since it displays it as a bytearray numeric values from -127 to 128 and without spaces in between values. Any value less than zero needs to have 256 added to it to get the true value.\
`CF_DumpVar` displays the binary data like it was viewed by a text editor, the HEX code is displayed on the left side with the ASCII value displayd on the right.

Here are two binary variable dumps using ``CFDump`` and ``CF_Dumpvar``. The first pair is from a Windows text file, the second pair a PNG image.

<img width="1106" height="556" alt="image" src="https://github.com/user-attachments/assets/75b73515-755e-4f04-8fcb-3ff7c7139ce7" />

## Images
``CF_Dumpvar`` displays the same struct info as ``CFDump`` but includes a view of the image, resized to 250px if larger on height or width.\
<img width="553" height="398" alt="image" src="https://github.com/user-attachments/assets/ada12a48-06cf-4b51-804e-6cbee1e42611" />

## PDF
> [!CAUTION]
> Be mindful of working on PDF objects, the "PageRotations" & "PageSizes" array is a "fast array" which is not thread safe. On a multi-user site that maniplates PDF documents to wrape it in a named exclusive cflock to prevent against race conditions.

Thumbnails of the PDFDocument are generated and displayed to the right of the PDF information output.\
The left side is the output of `CFDump`, the right from `CF_DumpVar`.\
The source PDF comes from https://www.adobe.com/cc-shared/assets/pdf/products/coldfusion-family/support-matrix-2025.pdf
<img width="995" height="1144" alt="image" src="https://github.com/user-attachments/assets/7f57e790-a08c-4783-b52e-fac3d94a5d73" />

## Queries
