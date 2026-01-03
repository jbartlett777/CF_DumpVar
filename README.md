# CF_DumpVar
A better CFDump

## Arrays

`CFDump` does not indicate if an array was created as a "fast array" which is not threadsafe.\
Left side is from `CFDump`, the right from `CF_DumpVar`
```
<CFSET Arr=ArrayNew(1,false)>
<CFSET Arr[1]="Foo">
<CFSET Arr[2]="Bar">
```
<img width="136" height="72" alt="image" src="https://github.com/user-attachments/assets/435a5be8-c000-48cf-849b-ff0a42c4c142" />

## PDF
> [!CAUTION]
> Be mindful of working on PDF objects, the "PageRotations" & "PageSizes" array is a "fast array" which is not thread safe. On a multi-user site that maniplates PDF documents to wrape it in a named exclusive cflock to prevent against race conditions.

Thumbnails of the PDFDocument are generated and displayed to the right of the PDF information output.\
The left side is the output of `CFDump`, the right from `CF_DumpVar`.\
The source PDF comes from https://www.adobe.com/cc-shared/assets/pdf/products/coldfusion-family/support-matrix-2025.pdf
<img width="995" height="1144" alt="image" src="https://github.com/user-attachments/assets/7f57e790-a08c-4783-b52e-fac3d94a5d73" />

## Queries
