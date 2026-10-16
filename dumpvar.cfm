<!--- Only process at the start of a tag calling --->
<CFIF StructKeyExists(variables,"ThisTag")>
	<CFIF ThisTag.ExecutionMode EQ "end">
		<CFEXIT method="exittag">
	</CFIF>
</CFIF>

<cfscript>
// Handle parameters if called as a structured tag
cfparam(name="Attributes.Var", Type="Any", Default="[Var not passed]");
cfparam(name="Attributes.Output", Type="String", Default="browser");
cfparam(Name="Attributes.Format", Type="String", Default="html");
cfparam(Name="Attributes.Abort", Type="Boolean", Default="false")
cfparam(Name="Attributes.Label", Type="String", Default="");
cfparam(Name="Attributes.Metainfo", Type="Boolean", Default="true");
cfparam(Name="Attributes.Top", Type="Numeric", Default="1000");
cfparam(Name="Attributes.Show", Type="String", Default="");
cfparam(Name="Attributes.Hide", Type="String", Default="");
cfparam(Name="Attributes.Keys", Type="Numeric", Default="1000");
cfparam(Name="Attributes.Expand", Type="Boolean", Default="true");
cfparam(Name="Attributes.ShowUDFs", Type="Boolean", Default="true");

// Following attributes are used internally for recursion
cfparam(Name="Attributes.RecurseInc", Type="Numeric", Default="0");
cfparam(Name="Attributes.IndentGap", Type="String", Default="#Chr(9)#");
cfparam(Name="Attributes.HonorCase", Type="Boolean", Default="false");

// Following Attributes don't register under Lucee so work around it
for (Key in "Label") { // String variables
	if (StructKeyExists(Attributes,Key) EQ "NO") Attributes[Key]="";
}

if (StructKeyExists(variables,"ThisTag")) {
	if (ThisTag.ExecutionMode EQ "start") {
		// Function was called as a custom tag, call the Dump function so it can recurse
		savecontent variable="DumpOutput" {
			writeoutput(DumpStart(Attributes.Var, Attributes.Output, Attributes.Format, Attributes.Abort, Attributes.Label, Attributes.Metainfo, Attributes.Top, Attributes.Show, Attributes.Hide, Attributes.Keys, Attributes.Expand, Attributes.ShowUDFs, Attributes.RecurseInc, Attributes.IndentGap, Attributes.HonorCase));
		}
		if (Attributes.Output EQ "Browser") {
			writeoutput(DumpOutput);
		} else {
			DumpSaveToFile(Attributes.Output, DumpOutput);
		}
		if (Attributes.Abort) abort;
	}
}

private function DumpSaveToFile (string FileName, string DumpOutput) {
	try {
		// Save to a file
		FileWrite(Arguments.FileName, Arguments.DumpOutput);
	} catch (any e) {
		writeoutput('[Not able to save output to #EncodeForHTML(Attributes.Output)#]');
	}
}

// Returns the ColdFusion app server & version
private array function DumpGetServerInfo() {
	var ServerInfo=ArrayNew(1);
	ServerInfo[1]=Server.ColdFusion.ProductName; // App Server [ColdFusion Server|Lucee]
	ServerInfo[2]=ListFirst(Server.ColdFusion.ProductVersion,"."); // Product version [2025|2023|2021|2018]

	return ServerInfo;
}

// Wrapper for Dumpvar function to allow it to recurse if called as a cf_tag
private function DumpStart(any Var,
					  String Output="Browser",
					  String Format="html",
					  Boolean Abort="false",
					  String Label="",
					  Boolean Metainfo="false",
					  Numeric Top=1000,
					  String Show="",
					  String Hide="",
					  Numeric Keys=1000,
					  Boolean Expand=false,
					  Boolean ShowUDFs=true,
					  Numeric RecurseInc="0",
					  String IndentGap=Chr(9),
					  Boolean HonorCase=false) {
	var DumpOutput="";

	savecontent variable="DumpOutput" {
		DumpVar(Var=Arguments.Var,Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
	}

	if (Arguments.Output EQ "Browser") {
		writeoutput(DumpOutput);
	} else {
		DumpSaveToFile(Arguments.Output, DumpOutput);
	}
	if (Arguments.Abort) abort;
}

public function DumpVar(any Var,
					  String Output="Browser",
					  String Format="html",
					  Boolean Abort="false",
					  String Label="",
					  Boolean Metainfo="false",
					  Numeric Top=1000,
					  String Show="",
					  String Hide="",
					  Numeric Keys=1000,
					  Boolean Expand=false,
					  Boolean ShowUDFs=true,
					  Numeric RecurseInc="0",
					  String IndentGap=Chr(9),
					  Boolean HonorCase=false) {

	var CollapseTable='onClick="cfdump_toggleTable(this);" style="cursor:pointer;" title="click to collapse"'; // Added to td/th blocks to collapse
	var CollapseRow='onClick="cfdump_toggleRow(this);" style="cursor:pointer;" title="click to collapse"';
	var CollapseQueryRow='onClick="cfdump_toggleRow_qry(this);" style="cursor:pointer;" title="click to collapse"';
	
	var LabelText="";
	var c=Chr(10);
	var Vartype=""; // Javasclass type
	var i=0; // Loop veriabe
	var count=0; // Counter
	var DispKeys=""; // Used to show/hide struct keys if needed
	var Tmp="";
	var ObjectType="";
	// Struct variables
	var StructFilter=""; // If the struct is filtered, holds how it's filtered
	var StructTruncated=""; // Set to "top " if struct list is limited by keys
	var StructDepth=0; // Holds the max depth of a struct
	var Indent=Replace(RepeatString(Arguments.IndentGap,Arguments.RecurseInc)," ","&nbsp;","All");
	// Query vars
	var QueryResult="";
	var QueryColumns="";
	var QuerySQL="";
	var Row=0;
	var Cell="";
	var CellValue="";
	var Class="";
	// Date values
	var TZ=""; // Timezone
	// Binary variables
	var BinaryTruncateAt=1000;
	var Binary=ArrayNew(2);
	var SmallCSS=""; // Used to set the CSS for a less than 8 byte block
	var Conversion="263A,263B,2665,2666,2663,2660,25AA,25AA,25CB,25A1," &
				   "2642,2640,266A,266B,263C,25BA,25C4,2195,203C,00B6," &
				   "00A7,2017,21A8,2191,2193,2192,2190,2310,2194,25B2," &
				   "25BC,00A0,0000,&quot;,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,&lt;," &
				   "0000,&gt;,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,0000,0000,0000,0000," &
				   "0000,0000,0000,0000,0000,0000,2302,00C7,0171,0039," &
				   "00E2,00E4,00E0,00E5,00E7,00EA,00EB,00E8,00EF,00EE," &
				   "00EC,00C4,00C5,00C9,00E6,00C6,00F4,00F6,00F2,00FB," &
				   "00F9,00FF,00D6,00DC,00A2,00A3,00A5,20A7,0192,00E1," &
				   "00ED,00F3,00FA,00F1,00D1,00AA,00BA,00BF,0001,00AC," &
				   "00BD,00BC,00A1,00AB,00BB,2591,2592,2593,2502,2524," &
				   "2561,2562,2556,2555,2563,2551,2557,255D,255C,255B," &
				   "2510,2514,2534,252C,251C,2500,253C,255E,255F,255A," &
				   "2554,2569,2566,2560,2550,256C,2567,2568,2564,2565," &
				   "2559,2558,2552,2553,256B,256A,2518,250C,2588,2584," &
				   "258C,2590,2580,03B1,03B2,0393,03A0,2211,03C3,03BC," &
				   "0001,03A6,04E8,2126,03B4,221E,0001,0404,2229,2261," &
				   "00B1,2265,2264,0001,0001,0001,2248,0001,25AA,25AA," &
				   "221A,207F,00B2,25A0";	// Unicode in Hex for ASCII 1-254,
											// "0000"=Pass character unaltered, "0001"=unknown character, display block
	// Image variables
	var ImgInfo="";
	var ThumbnailMaxResize=200; // Maximum width or height of the image thumbnail
	// Spreadsheet vars
	var SheetFile=""; // Holds the temp file for a sheet
	var SheetName=""; // Name of the current sheet being processed
	var SheetNum=0;
	var SheetRows=0; // Number of rows in shceet
	var SheetCols=0; // Number of cols in sheet
	var SheetInfo=StructNew();
	var SheetData=StructNew();
	var OrderedSheetList="";
	var CellData=ArrayNew(2); // Holds sheet cell data
	var SheetLastRow=0;
	var SheetList="";
	var Cell="";
	var Col=0;
	// PDF vars
	var Scale=0;
	var PageImage="";
	var Thumbnail="";
	var TempFile="";
	var TempDir="";
	var PDFThumbnails=ArrayNew(1);
	var PDFDirContents="";
	// WDDX vars
	var WDDXDecoded="";
	// Server Information (CF vs Lucee, version)
	var ServerInfo=DumpGetServerInfo();
	// Text handling
	var EndPre="";

	// If format is text and first time into function, output a <pre>
	if (Arguments.Format EQ "text" AND StructKeyExists(Request,"CFDumpVarPre") EQ "NO") {
		writeoutput('<pre>');
		Request.CFDumpVarPre=1;
	}

	// Get Javaclass type
	try {
		VarType=ListLast(Arguments.Var.getClass(),".");
	} catch (any e) {
		// Lucee did not identify the variable type
		VarType="Unknown";
	}
	
	// Validation
	if (StructKeyExists(Attributes,"Output") AND Attributes.Output EQ "console") {
		writeoutput('CF_Dumpvar does not support output="console"');
		abort;
	}

	if (Trim(Arguments.Label) NEQ "") LabelText=Arguments.Label & "&nbsp;-&nbsp;";

	// Determine if we need to output the CSS & JavaScript support code
	if (IsSimpleValue(Arguments.Var) EQ "NO" AND Arguments.Format EQ "html") OutputDumpSupportCF();

	// Handle image objects
	if (IsImage(Arguments.Var)) {
		// Resize image to a max 256 px thumbnail
		ImgInfo=Arguments.Var.info();

		// Resize if needed
		Thumbnail=Arguments.Var;

		if (ServerInfo[1] EQ "ColdFusion Server" OR (ServerInfo[1] EQ "Lucee" AND ListFirst(ServerInfo[2]) GT 10)) {
			// Resize is not available on Lucee 4
			if (ImgInfo.Width GT ThumbnailMaxResize OR ImgInfo.height GT ThumbnailMaxResize) {
				// Compute new size
				if (ImgInfo.Width EQ ImgInfo.Height) { // Square image
					Thumbnail.Resize(ThumbnailMaxResize,ThumbnailMaxResize);
				} else if (ImgInfo.Width GT ImgInfo.Height) { // Landscape
					ImgAspectRatio=ImgInfo.Width / ImgInfo.Height;
					Thumbnail.Resize(ThumbnailMaxResize * ImgAspectRatio,ThumbnailMaxResize);
				} else { // Portrait
					ImgAspectRatio=ImgInfo.Height / ImgInfo.Width;
					Thumbnail.Resize(ThumbnailMaxResize,ThumbnailMaxResize * ImgAspectRatio);
				}
			}
		}
		// Output the thumbnail with the same color scheme as a binary file
		writeoutput('<table class="cfdump_binary">' & C &
					'	<tr>' &
					'		<th class="binary" colspan="2" #CollapseTable#>#LabelText#image</td>' & C &
					'	</tr>' & C &
					'	<tr>' & C &
					'		<td>' & C);
		DumpVar(Var=ImgInfo,Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
		writeoutput('		</td>' & C &
					'		<td class="binary">' & C &
					'			<img src="data:image/png;base64,' & ToBase64(Thumbnail) & '">' & C &
					'		</td>' & C &
					'	</tr>' & C &
					'</table>' & C);
		
		return;
	}

	// Handle WDDX objects
	if (IsWDDX(Arguments.Var)) {
		// Convert the WDDX object
		cfwddx(action="wddx2cfml", input="#Arguments.Var#", output="WDDXDecoded");
		if (Arguments.Format EQ "html") {
			writeoutput('<table class="cfdump_wddx">' & C &
						'	<tr>' & C &
						'		<th class="wddx" colspan="2" #CollapseTable#>#LabelText#wddx encoded</th>' & C &
						'	</tr>' & C &
						'	<tr>' & C &
						'		<td>');
			DumpVar(Var=WDDXDecoded,Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
			writeoutput('</td>' & C &
						'	</tr>' & C &
						'</table>');
		} else { // text
			writeoutput('#Indent##LabelText#wddx encoded' & C);
			DumpVar(Var=WDDXDecoded,Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Handle PDF objects
	if (ServerInfo[1] EQ "Lucee" AND IsPDFObject(Arguments.Var)) {
		writedump(Arguments.Var);
		return;
	}
	if (VarType EQ "PDFDocWrapper" AND ServerInfo[1] EQ "ColdFusion Server") {
		if (Arguments.Format EQ "html") {
			writeoutput('<table border="0" cellspacing="0" cellpadding="0">' & C &
						'	<tr>' & C &
						'		<td valign="top">' & C);
			// Dump the PDF info block
			DumpVar(Var=StructCopy(Arguments.Var),Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label="PDFDocument",Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
			writeoutput('		</td>' & C &
						'		<td>&nbsp;</td>' & C &
						'		<td valign="top">' & C &
						'			<table class="cfdump_struct">' & C &
						'				<tr>' & C &
						'					<th class="struct" #CollapseTable#>PDF Thumbnails</tr>' & C &
						'				</tr>' & C &
						'				<tr>' & C &
						'					<td valign="top">' & C);
			// To extract the thumbnails, we need to first save the PDF object to a temp file
			TempFile=getTempFile(getTempDirectory(),"cfdumpvar_PDF_");
			cfpdf(action="write", destination="#TempFile#", overwrite=true, source="Arguments.Var");

			// Extract thumbnails - get a temp file, convert it into a directory
			Scale=Int(ThumbnailMaxResize / Arguments.Var.PageSizes[1].Height / 0.01); // Scale the thumbnail down
			TempDir=getTempFile(getTempDirectory(),"cfdumpvar_PDF_");
			FileDelete(TempDir);
			cfpdf(action="Thumbnail", source="#TempFile#", imagePrefix="pdf", destination="#TempDir#", format="png", scale="#Scale#", Resolution="High");

			// Delete the temp PDF file
			FileDelete(TempFile);

			// Fetch the thumbnail files
			PDFDirContents=DirectoryList(TempDir, true);

			// Loop over the thumbnails and output them in a floating grid
			for (i=1; i LTE ArrayLen(PDFDirContents); i++) {
				PageImage=FileReadBinary(PDFDirContents[i]);
				FileDelete(PDFDirContents[i]);
				writeoutput('<img src="data:image/png;base64,' & ToBase64(PageImage) & '">' & C);
			}
			// Delete the temp dir
			DirectoryDelete(TempDir);

			// Close out the table
			writeoutput('					</td>' & C &
						'				</tr>' & C &
						'			</table>' & C &
						'		</td>' & C &
						'	</tr>' & C &
						'</table>' & C);
		} else { // Text format
			DumpVar(Var=StructCopy(Arguments.Var),Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Handle spreadsheet
	if (VarType EQ "ExcelInfo") {
		if (ServerInfo[1] EQ "ColdFusion Server" AND ListFirst(ServerInfo[2]) LTE 2023) {
			// CF 2023 and earlier does not support the Visiblity flag that this tag uses to parse out sheet names that potentially include commas which breaks the list.
			// TO DO: Add support for CF2023 and earlier
			DumpVar(var=StructCopy(Arguments.Var));
			return;
		}
		SheetInfo=SpreadSheetInfo(Arguments.Var);
		// Determine sheet order, can't trust the list to be a comma delimited list
		SheetList=SheetInfo.SheetNames; // List of sheets, but may not be a true list to itterate over due to embedded commas
		while (SheetList NEQ "") {
			// Find the next sheet
			for (SheetName in StructKeyList(SheetInfo.VISIBILITY)) {
				if (Left(SheetList,Len(SheetName)) EQ SheetName) {
					OrderedSheetList=ListAppend(OrderedSheetList,SheetName,"|");
					if (SheetList EQ SheetName) {
						SheetList="";
					} else {
						SheetList=Mid(SheetList,Len(SheetName) + 2,Len(SheetList));
					}
					SpreadsheetSetActiveSheet(Arguments.Var,SheetName);
					CellData=Arraynew(2);
					for (Row=1; Row LTE 1000; Row++) { // Fetch the first 1000 rows
						for (Col=1; Col LTE SpreadsheetGetColumnCount(Arguments.Var,SheetName); Col++) {
							Cell=SpreadsheetGetCellValue(Arguments.Var,Row,Col);
							CellData[Row][Col]=Cell;
							if (Cell NEQ "") SheetLastRow=Row;
						}
					}
					// Delete unused rows
					if (SheetLastRow GT 1) {
						while (ArrayLen(CellData) GT SheetLastRow) {
							ArrayDeleteAt(CellData,SheetLastRow + 1);
						}
					}
					SheetData[SheetName]=CellData;
				}
			}
		}
		// TODO: Extract styles/spans
		// TODO: Add formula & comment information

		// Add more info to the sheet information struct
		SheetInfo.Sheets=ArrayNew(1);
		for (SheetNum=1; SheetNum LTE ListLen(OrderedSheetList,"|"); SheetNum++) {
			SheetName=ListGetAt(OrderedSheetList,SheetNum,"|");
			SheetInfo.Sheets[SheetNum]=StructNew();
			SheetInfo.Sheets[SheetNum].SheetName=SheetName;
			SheetInfo.Sheets[SheetNum].Rows=ArrayLen(SheetData[SheetName]);
			SheetInfo.Sheets[SheetNum].Cols=ArrayLen(SheetData[SheetName][1]);
		}
		// Output the sheet data like a normal dump
		DumpVar(Var=SheetInfo,Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);

		if (Arguments.Format EQ "html") {
			// Output CSS for spreadsheets
			OutputExcelCSS();
			// Generate the sheets
			writeoutput('<div class="Dump_Excel-workbook"><div class="Dump_Excel-sheets">' & C);
			for (SheetNum=1; SheetNum LTE ListLen(OrderedSheetList,"|"); SheetNum++) {
				SheetName=ListGetAt(OrderedSheetList,SheetNum,"|");
				if (SheetNum EQ 1) {
					writeoutput('	<div id="Dump_Excel_#Hash(Sheetname)#" class="Dump_Excel-sheet active"> <!-- Sheet: [' & EncodeForHTML(SheetName) & '] -->' & C);
				} else {
					writeoutput('	<div id="Dump_Excel_#Hash(Sheetname)#" class="Dump_Excel-sheet"> <!-- Sheet: [' & EncodeForHTML(SheetName) & '] -->' & C);
				}
				writeoutput('		<table class="Dump_Excel">' & C &
							'			<colgroup>' & C &
							'				<col style="width:40px">' & C &
							RepeatString('				<col>' & C,ArrayLen(SheetData[SheetName][1])) &
							'			</colgroup>' & C &
							'			<thead>' & C &
							'				<tr>' & C &
							'					<th></th>' & C);
				for (i=1; i LTE ArrayLen(SheetData[SheetName][1]); i++) {
					if (i LTE 26) {
						// Excel columns A-Z
						writeoutput('					<th>#Chr(64+i)#</th>' & C);
					} else {
						// Excel columns AA on
						writeoutput('					<th>#Chr(64 + Int((i-1)/26))##Chr(65 + (i-1) MOD 26)#-#(i-1) MOD 26#</th>' & C);
					}
				}
				writeoutput('				</tr>' & C &
							'			</thead>' & C &
							'			<tbody>' & C);
				for (Row=1; Row LTE ArrayLen(SheetData[SheetName]); Row++) {
					writeoutput('				<tr>' & C &
								'					<td class="RowHeader">#Row#</td>' & C);
					for (Col=1; Col LTE ArrayLen(SheetData[SheetName][Row]); Col++) {
						if (REFind("^[+-]?\s*[$€£¥]?\s*(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?$",SheetData[SheetName][Row][Col])) { // Match numbers including commas, decimals, and currrency
						//if (IsNumeric(SheetData[SheetName][Row][Col])) {
							writeoutput('					<td class="Number">');
						} else {
							writeoutput('					<td>');
						}
						writeoutput(EncodeForHTML(SheetData[SheetName][Row][Col]) & '</td>' & C);
					}
					writeoutput('				</tr>' & C);
				}
				writeoutput('			</tbody>' & C &
							'		</table>' & C &
							'	</div>' & C);
			}
			// Generate the tab group
			writeoutput('	<div class="Dump_Excel-tabs-container">' & C &
						'		<div class="Dump_Excel_tab active" data-target="Dump_Excel_' & Hash(ListFirst(OrderedSheetList,"|")) & '">' & EncodeForHTML(ListFirst(OrderedSheetList,"|")) & '</div>' & C);
			for (Row=2; Row LTE ListLen(OrderedSheetList,"|"); Row++) {
				writeoutput('		<div class="Dump_Excel_tab" data-target="Dump_Excel_' & Hash(ListGetAt(OrderedSheetList,Row,"|")) & '">' & EncodeForHTML(ListGetAt(OrderedSheetList,Row,"|")) & '</div>' & C);
			}
			writeoutput('	</div>' & C &
						'</div></div>' & C);
			OutputExcelJS();
		} // End HTML block, no text output of spreadsheet
		
		return;
	}

	// Handle Binary
	if (IsBinary(Arguments.Var)) {
		Row="";
		Str="";
		for (i=1; i LTE Min(BinaryTruncateAt,ArrayLen(Arguments.Var)); i++) {
			v=Arguments.Var[i];
			if (v LT 0) v=v + 256;
			// Binary data is representeed by an integer array -128 to 127. Add 128 to the absolute value
			Row=Row & Replace(RJustify(FormatBaseN(v,16),2)," ","0") & " "; // Append hex string
			// Convert binary to character
			if (v EQ 0 OR v EQ 255) { //Nulls
				Str=Str & "&##9642;";
			} else {
				tmp=ListGetAt(Conversion,v);
				if (tmp EQ "0000") {
					Str=Str & Chr(v);
				} else if (tmp EQ "0001") {
					Str=Str & "&##9642;";
				} else if (Left(tmp,1) EQ "&") {
					Str=Str & tmp;
				} else {
					Str=Str & "&##" & InputBaseN(tmp,16) & ";";
				}
			}
			if (i MOD 8 EQ 0) {
				NR=ArrayLen(Binary) + 1;
				Binary[NR][1]=UCase(Row);
				Binary[NR][2]=Str;
				Row="";
				Str="";
			}
		}
		if (Str NEQ "") {
			NR=ArrayLen(Binary) + 1;
			Binary[NR][1]=Row;
			Binary[NR][2]=Str;
		}

		if (Arguments.Format EQ "html") {
			OutputBinaryCSS();  // Send the binary CSS if not already

			writeoutput('<table class="cfdump_binary">' & C &
						'	<tr>' &
						'		<th class="binary" #CollapseTable#>#LabelText#binary</td>' & C &
						'	</tr>' & C &
						'	<tr>' & C &
						'		<td class="binary">' & C);

			if (ArrayLen(Binary) EQ 1) SmallCSS="Small";
			writeoutput('<div class="DumpBinaryOuterWrap">' & C &
						'	<div class="DumpBinaryOuterDiv">' & C &
						'		<div class="DumpBinaryHexDiv#SmallCSS#">' & C);
			for (i=1; i LTE ArrayLen(Binary); i++) {
				if (Len(Binary[i][1]) LT 24) {
					SmallCSS="Small";
				} else {
					SmallCSS="";
				}
				writeoutput('			<div class="BinaryDataHex#SmallCSS#">' & Binary[i][1] & '</div>' & C);

			}
			if (ArrayLen(Arguments.Var) GT BinaryTruncateAt) writeoutput('[truncated]');
			if (ArrayLen(Binary) EQ 1) {
				SmallCSS="Small";
			} else {
				SmallCSS="";
			}
			writeoutput('		</div>' & C &
						'		<div class="DumpBinaryASCIIDiv#SmallCSS#">' & C);
			for (i=1; i LTE ArrayLen(Binary); i++) {
				if (Len(Binary[i][1]) LT 24) {
					SmallCSS="Small";
				} else {
					SmallCSS="";
				}
				writeoutput('			<div class="BinaryDataASCII#SmallCSS#">' & Binary[i][2] & '</div>' & C);

			}
			writeoutput('		</div>' & C &
						'	</div>' & C &
						'</div>' & C);

			writeoutput('		</td>' & C &
						'	</tr>' & C &
						'</table>' & C);
		} else { // format=text
			writeoutput('#LabelText#[binary]' & C);
			for (i=1; i LTE ArrayLen(Binary); i++) {
				writeoutput(Binary[i][1] & Binary[i][2] & C);
			}
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Handle query object
	if (ListFindNoCase("QueryTable,QueryImpl,FileListTable",VarType)) {
		if (ServerInfo[1] EQ "ColdFusion Server") {
			QueryResult=QueryGetResult(Arguments.Var);
			if (StructKeyExists(variables,"QueryResult")) {
				QuerySQL=EncodeForHTML(StripCR(QueryResult.SQL));
			} else {
				QuerySQL="";
			}
		}
		QueryColumns=GetMetadata(Arguments.var);
		tmp=ReMatch("&##xa;(&##x9;)+",QuerySQL);
		if (ArrayLen(tmp)) QuerySQL=tmp[1] & QuerySQL;
		QuerySQL=Replace(QuerySQL,"&##xa;&##x9;","&##xa;","All");

		if (Arguments.Format EQ "html") {

			if (Arguments.metainfo AND ServerInfo[1] EQ "ColdFusion Server" AND VarType NEQ "FileListTable") {
				writeoutput('<table class="cfdump_query">' & C &
							'	<tr>' & C &
							'		<th colspan="2" class="query" #CollapseTable#>#LabelText#query</td>' & C &
							'	</tr>' & C &
							'	<tr>' & C &
							'		<td class="query" #CollapseRow#>RESULTSET</td>' & C &
							'		<td>');
			}

			writeoutput('<table class="cfdump_query">' & C &
						'	<tr>' & C &
						'		<th colspan="#ArrayLen(QueryColumns) + 1#" class="query" #CollapseTable#>query</td>' & C &
						'	</tr>' & C &
						'	<tr>' & C &
						'		<td class="query">&nbsp;</td>' & C);
			// Output coolumn headers
			for (Row=1; Row LTE Min(1000,ArrayLen(QueryColumns)); Row++) {
				writeoutput('		<td class="query">#EncodeForHTML(QueryColumns[Row].Name)#</td>' & C);
			}
			writeoutput('	</tr>' & C &
						'	<tr>' & C &
						'		<td class="query">&nbsp;</td>' & C);
			// Output coolumn types
			for (Row=1; Row LTE ArrayLen(QueryColumns); Row++) {
				writeoutput('		<td class="query">#EncodeForHTML(QueryColumns[Row].TypeName)#</td>' & C);
			}
			writeoutput('	</tr>');
			// Output the table
			for (Row=1; Row LTE Arguments.Var.RecordCount; Row++) {
				writeoutput('	<tr>' & C &
							'		<td class="query" #CollapseQueryRow#>#Row#</td>' & C);
				for (Cell=1; Cell LTE Min(1000,ArrayLen(QueryColumns)); Cell++) {
					// Format cell & value
					CellValue=Arguments.Var[QueryColumns[Cell].Name][Row];
					if (IsSimpleValue(CellValue)) {
						if (IsNumeric(CellValue)) {

						} else if (IsDate(CellValue)) {
							TZ="";
							if (Find("+",CellValue)) TZ="Z";
							if (Find(".",CellValue)) {
								CellValue=DateTimeFormat(CellValue,"yyyy-mm-dd HH:nn:ss.l#TZ#");
							} else {
								if (Find(":",CellValue)) {
									CellValue=DateTimeFormat(CellValue,"yyyy-mm-dd HH:nn:ss#TZ#");
								} else {
									CellValue=DateTimeFormat(CellValue,"yyyy-mm-dd#TZ#");
								}
							}
							CellValue=Replace(CellValue," ","&nbsp;","All");
						}
					} else {
						savecontent variable="CellValue" {
							DumpVar(Var=Arguments.Var[QueryColumns[Cell].Name][Row],Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
						}
					}
					if (Trim(CellValue) EQ "") CellValue="[empty string]";

					writeoutput('		<td>#CellValue#</td>' & C);
				}
				writeoutput('	</tr>' & C);
			}
			writeoutput('</table>');

			if (StructKeyExists(variables,"QueryResult") AND Arguments.metainfo AND ServerInfo[1] EQ "ColdFusion Server") {
				writeoutput('		</td>' & C &
							'	</tr>' & C &
							'	<tr>' & C &
							'		<td class="query" #CollapseRow#>CACHED</td>' & C &
							'		<td class="Dump_Cell">#QueryResult.Cached#</td>' & C &
							'	</tr>' & C &
							'	<tr>' & C &
							'		<td class="query" #CollapseRow#>EXECUTIONTIME</td>' & C &
							'		<td class="Dump_Cell">#NumberFormat(QueryResult.ExecutionTime,"9,999")#ms</td>' & C &
							'	</tr>' & C &
							'	<tr>' & C &
							'		<td class="query" #CollapseRow#>SQL</td>' & C &
							'		<td class="Dump_Cell"><pre>#QuerySQL#</pre></td>' & C &
							'	</tr>' & C);
			}
			if (VarType NEQ "FileListTable") writeoutput('</table>' & C);

		} else { // format="text"
			if (Arguments.metainfo AND ServerInfo[1] EQ "ColdFusion Server") {
				writeoutput('#Indent#CACHED: ' & QueryResult.Cached & C &
							'#Indent#EXECUTIONTIME: ' & Trim(NumberFormat(QueryResult.ExecutionTime,"9,999")) & 'ms' & C &
							'#Indent#SQL: ' & QuerySQL & C &
							'#Indent#RESULTSET:' & C);
			}
			for (Row=1; Row LTE Arguments.Var.RecordCount; Row++) {
				writeoutput(C & Indent & Chr(9) & '[Record ## #Row#]' & C);
				for (Cell=1; Cell LTE Min(1000,ArrayLen(QueryColumns)); Cell++) {
					writeoutput(Indent & Chr(9) & QueryColumns[Cell].Name & ': ');
					DumpVar(Var=Arguments.Var[QueryColumns[Cell].Name][Row],Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
					writeoutput(C);
				}
			}
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Handle Array
	if (ListFind("Array,FastArray,Vector,ArrayImpl,ArrayClassic",VarType)) {

		if (VarType EQ "FastArray") ObjectType="fast ";
		ObjectType=ObjectType & "array";
		if (ArrayLen(Arguments.Var) EQ 0) ObjectType=ObjectType & " (empty)";

		if (Arguments.Format EQ "html") {
			writeoutput('<table class="cfdump_array">' & C &
						'	<tr>' & C &
						'		<th colspan="2" class="array" #CollapseTable##LabelText#>#ObjectType#</th>' & C &
						'	</tr>' & C);
			for (i=1; i LTE ArrayLen(Arguments.var); i++) {
				writeoutput('	<tr>' & C &
							'		<td class="array Dump_Align_Right" width="1" #CollapseRow#>#i#</td>' & C &
							'		<td class="Dump_Data">');
				if (ArrayIsDefined(Arguments.Var,i)) {
					DumpVar(Var=Arguments.Var[i],Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
				} else {
					writeoutput('[undefined array element]');
				}
				writeoutput('</td>' & C &
				'	</tr>' & C);
			}
			writeoutput('</table>' & C);
		} else { // format text
			writeoutput('#Indent##LabelText#[array]' & C & C);
			for (i=1; i LTE ArrayLen(Arguments.var); i++) {
				writeoutput("#Indent##i#) ");
				if (ArrayIsDefined(Arguments.Var,i)) {
					if (ListLast(Arguments.Var[i].getClass(),".") EQ "String") {
						writeoutput(Arguments.Var[i] & C);
					} else {
						DumpVar(Var=Arguments.Var[i],Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
					}
				} else {
					writeoutput('[undefined array element]' & C);
				}
			}
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Handle struct
	if (ServerInfo[1] EQ "Lucee" AND IsStruct(Arguments.Var)) VarType="StructImpl";
	if (ListFind("CgiScope,Struct,StructOrdered,CaseSensitiveStruct,OrderedCaseSensitiveStruct,VariablesImpl,StructImpl",VarType)) {
		StructDepth=FindStructMaxDepth(Arguments.Var,1);
		if (ListFind("StructOrdered,OrderedCaseSensitiveStruct",VarType)) {
			// Struct is ordered, don't sort
			DispKeys=StructKeyList(Arguments.Var);
		} else {
			// CFDUMP lists keys in case sensitive alpha order
			DispKeys=ListSort(StructKeyList(Arguments.Var),"text");
		}
		// If showing filtered keys
		if (Trim(Arguments.Show) NEQ "") {
			DispKeys=""; // Rebuild key list
			// If showing keys, put in the requested keys if existing
			for (Key in StructKeyList(Arguments.Var)) {
				if (ListFind("CgiScope,Struct,StructOrdered,VariablesImpl,StructImpl",VarType) OR Arguments.HonorCase EQ false) {
					if (ListFindNoCase(Arguments.Show,Key)) DispKeys=ListAppend(DispKeys,Key);
				} else {
					if (ListFind(Arguments.Show,Key)) DispKeys=ListAppend(DispKeys,Key);
				}
			}
		} else if (Trim(Arguments.Hide) NEQ "") {
			for (Key in Trim(Arguments.Hide)) {
				if (ListFind("CgiScope,Struct,StructOrdered,VariablesImpl,StructImpl",VarType) OR Arguments.HonorCase EQ false) {
					Loc=ListFindNoCase(DispKeys,Key);
				} else {
					Loc=ListFind(DispKeys,Key);
				}
				if (Loc GT 0) DispKeys=ListDeleteAt(DispKeys,Loc);
			}
		}
		if (Arguments.HonorCase EQ true) LabelText = "[Case Honored] " & LabelText;


		if (Arguments.Keys GT 0) {
			// Limited number of keys requested, remove those in excess
			if (ListLen(DispKeys) GT Arguments.Keys) {
				StructTruncated="top ";
				while (ListLen(DispKeys) GT Arguments.Keys) {
					DispKeys=ListDeleteAt(DispKeys,ListLen(DispKeys));
				}
			}
		}

		if (Attributes.RecurseInc EQ 0) {
			switch(VarType) {
				default: ObjectType="struct";break;
				case "StructOrdered": ObjectType="struct (ordered)";break;
				case "CaseSensitiveStruct": ObjectType="casesensitive struct";break;
				case "OrderedCaseSensitiveStruct": ObjectType="casesensitive struct (ordered)";break;
			}
		} else {
			ObjectType=VarType;
		}
		if ((Arguments.Top GT 0 AND Arguments.Top NEQ 1000) AND Arguments.RecurseInc EQ 0) StructFilter=ListAppend(StructFilter," #Arguments.Top# of #StructDepth# level#DumpS(StructDepth)#");
		if (ListLen(StructKeyList(Arguments.Var)) NEQ ListLen(DispKeys)) StructFilter=ListAppend(StructFilter," #StructTruncated#" & ListLen(DispKeys) & " of " & ListLen(StructKeyList(Arguments.Var)) & " key" & DumpS(ListLen(StructKeyList(Arguments.Var))) & " shown");
		if (StructFilter NEQ "") StructFilter=" [Filtered -#StructFilter#]";
		if (StructKeyList(Arguments.Var) EQ "") StructFilter=StructFilter & " [empty]";

		if (Arguments.Format EQ "html") {
			writeoutput('<table class="cfdump_struct">' & C &
						'	<tr>' & C &
						'		<th class="struct" colspan="2" #CollapseTable#>#LabelText##ObjectType##StructFilter#' & C &
						'</th>' & C &
						'	</tr>' & C);
			for (Key in DispKeys) {
				if (count GT Arguments.Keys) break;
				writeoutput('	<tr>' & C &
							'		<td class="struct" #CollapseRow#>' & Key & '</td>' & C &
							'		<td>');
				if (ListLast(Arguments.Var[Key].getClass(),".") EQ "String") {
					writeoutput(Arguments.Var[Key] & C);
				} else {
					if (Arguments.RecurseInc GTE Arguments.Top) {
						writeoutput('[filtered]');
					} else {
						DumpVar(Var=Arguments.Var[Key],Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
					}
				}
				writeoutput('</td>' & C &
							'	</tr>' & C);
			}
			writeoutput('</table>' & C);
		} else { // Format=text
			writeoutput('#Indent#[#ObjectType#]#StructFilter#' & C & C);
			for (Key in DispKeys) {

				writeoutput(Indent & Key & ": ");
				if (ListLast(Arguments.Var[Key].getClass(),".") EQ "String") {
					writeoutput(Arguments.Var[Key] & C);
				} else {
					if (Arguments.RecurseInc GTE Arguments.Top) {
						writeoutput('[filtered]');
					} else {
						DumpVar(Var=Arguments.Var[Key],Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
					}
				}
			}
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Check for Base64 encoded data, needs to be after image processing
	if (VarType EQ "String" AND REFindNoCase("[a-z0-9+\/]+=",Arguments.Var)) {
		if (Arguments.Format EQ "html") {
			// Convert from Base64 to original form and dump it
			writeoutput('<table class="cfdump_binary">' & C &
						'	<tr>' & C &
						'		<th class="binary" colspan="2" #CollapseTable#>#LabelText#base64&nbspencoded</th>' & C &
						'	</tr>' & C &
						'	<tr>' & C &
						'		<td>');
			DumpVar(Var=ToBinary(Arguments.Var),Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
			writeoutput('</td>' & C &
						'	</tr>' & C &
						'</table>');
		} else { // text format
			DumpVar(Var=ToBinary(Arguments.Var),Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs,RecurseInc=Arguments.RecurseInc + 1,IndentGap=Arguments.IndentGap,HonorCase=Arguments.HonorCase);
			CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		}
		
		return;
	}

	// Output simple values and exit
	if (ListFind("String,Integer,Boolean,Double,CFDouble,Long",VarType)) {
		if (Trim(Arguments.Var) EQ "") {
			writeoutput('[empty string]');
		} else {
			writeoutput(EncodeForHTML(Arguments.Var));
		}
		if (Arguments.Format EQ "text") writeoutput(C);
		CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		return;
	}

	if (VarType EQ "Date") {
		if (IsDate(Arguments.Var)) {
			if (Find(Arguments.Var,":")) {
				writeoutput(DateTimeFormat(Arguments.Var,"yyyy-mm-dd HH:nn:ss"));
			} else {
				writeoutput(DateFormat(Arguments.Var,"yyyy-mm-dd"));
			}
		} else {
			writeoutput(Arguments.Var);
		}
		CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
		return;
	}

	// Pass on unhandled variables to cfdump
	writeoutput("Unknown type [#VarType#]<br>");
	writeoutput("IsArray: " & IsArray(Arguments.Var) & "<br>");
	writeoutput("IsBinary: " & IsBinary(Arguments.Var) & "<br>");
	writeoutput("IsBoolean: " & IsBoolean(Arguments.Var) & "<br>");
	writeoutput("IsCustomFunction: " & IsCustomFunction(Arguments.Var) & "<br>");
	writeoutput("IsDate: " & IsDate(Arguments.Var) & "<br>");
	writeoutput("IsImage: " & IsImage(Arguments.Var) & "<br>");
	writeoutput("IsJSON: " & IsJSON(Arguments.Var) & "<br>");
	writeoutput("IsNULL: " & IsNULL(Arguments.Var) & "<br>");
	writeoutput("IsNumeric: " & IsNumeric(Arguments.Var) & "<br>");
	writeoutput("IsNumericDate: " & IsNumericDate(Arguments.Var) & "<br>");
	writeoutput("IsObject: " & IsObject(Arguments.Var) & "<br>");
	writeoutput("IsQuery: " & IsQuery(Arguments.Var) & "<br>");
	writeoutput("IsSimpleValue: " & IsSimpleValue(Arguments.Var) & "<br>");
	writeoutput("IsSpreadsheetObject: " & IsSpreadsheetObject(Arguments.Var) & "<br>");
	writeoutput("IsStruct: " & IsStruct(Arguments.Var) & "<br>");
	writeoutput("IsWDDX: " & IsWDDX(Arguments.Var) & "<br>");
	if (ListFirst(ServerInfo[2]) GTE 2025) writeoutput("IsXML: " & IsXML(Arguments.Var) & "<br>");
	//writedump(Var=Arguments.Var,Output=Arguments.Output,Format=Arguments.Format,Abort=Arguments.Abort,Label=Arguments.Label,Metainfo=Arguments.Metainfo,Top=Arguments.Top,Show=Arguments.Show,Hide=Arguments.Hide,Keys=Arguments.Keys,Expand=Arguments.Expand,ShowUDFs=Arguments.ShowUDFs);
	CFDumpVar_CloseOutTextOutput(Arguments.RecurseInc);
	return;
}

private string function CFDumpVar_CloseOutTextOutput(RecurseInc) {
	if (Arguments.RecurseInc GT 1) return "";
	if (StructKeyExists(Request,"CFDumpVarPre")) {
		writeoutput('</pre>');
		StructDelete(Request,"CFDumpVarPre");
	}
}

// Return a "s" if the passed in numeric value is not 1
private string function DumpS(integer i) {
	if (Arguments.i NEQ 1) return "s";
	return "";
}

// Recurse through a struct to find it's max depth
private function FindStructMaxDepth(Struct InStruct,string InDepth="1") { // 2nd parameter set to string to support different engines
	var Depth=Val(Arguments.InDepth);
	var Key="";
	var NextDepth=Val(Arguments.InDepth);

	if (Depth EQ 0) Depth=1;
	if (NextDepth EQ 0) NextDepth=1;
	NextDepth=NextDepth + 1;

	for (Key in StructKeyList(Arguments.InStruct)) {
		if (ListFind("CgiScope,Struct,StructOrdered,CaseSensitiveStruct,OrderedCaseSensitiveStruct",ListLast(Arguments.InStruct[Key].getClass(),"."))) {
			Depth=Max(Depth,FindStructMaxDepth(Arguments.InStruct[Key],NextDepth));
		}
	}
	return Depth;
}

private string function GetVarType(string Type) {
	var ObjectType=Arguments.Type;
	switch(ListLast(Arguments.Var.getClass(),".")) {
		case "Struct": ObjectType="struct";break;
		case "StructOrdered": ObjectType="struct (ordered)";break;
		case "CaseSensitiveStruct": ObjectType="casesensitive struct";break;
		case "OrderedCaseSensitiveStruct": ObjectType="casesensitive struct (ordered)";break;
	}
	return ObjectType;
}

private function OutputExcelCSS() {
	// Excel CSS & Javascript generatd by ChatGPT and then altered for use
	if (StructKeyExists(Request,"cfdump_excel_css")) return;
	Request.cfdump_excel_css=true;
	writeoutput('
<style type="text/css">
/* Base table */
.Dump_Excel {
	border-collapse: collapse;
	border-spacing: 0;
	font-family: Calibri, "Segoe UI", Arial, sans-serif;
	font-size: 11pt;
	background-color: ##ffffff;
	color: ##000000;
}

/* All cells */
.Dump_Excel td,
.Dump_Excel th {
	border: 1px solid ##d9d9d9; /* Excel gridline color */
	padding: 2px 6px;
	height: 20px;
	vertical-align: middle;
	white-space: nowrap;
	overflow: hidden;
}

/* Column headers (A, B, C...) */
.Dump_Excel thead th {
	background-color: ##f3f3f3;
	font-weight: normal;
	text-align: center;
	color: ##000000;
	border-bottom: 1px solid ##bfbfbf;
}

/* Row headers (1, 2, 3...) */
.Dump_Excel .RowHeader {
	background-color: ##f3f3f3;
	text-align: right;
	padding-right: 6px;
	border-right: 1px solid ##bfbfbf;
	font-weight: normal;
}

/* Default alignment */
.Dump_Excel td {
	text-align: left;
}

/* Numeric cells */
.Dump_Excel .Number {
	text-align: right;
}

/* Centered cells */
.Dump_Excel .Center {
	text-align: center;
}

/* Bold text */
.Dump_Excel .Bold {
	font-weight: bold;
}

/* Italic text */
.Dump_Excel .Italic {
	font-style: italic;
}

/* Selected cell */
.Dump_Excel .Selected {
	outline: 2px solid ##217346; /* Excel green */
	outline-offset: -2px;
	background-color: ##ffffff;
}

/* Selected range */
.Dump_Excel .SelectedRange {
	background-color: ##e2f0d9;
}

/* Error cell (e.g., ##DIV/0!) */
.Dump_Excel .Error {
	color: ##9c0006;
background-color: ##ffc7ce;
}

/* Disabled / empty cells */
.Dump_Excel .Empty {
	color: ##808080;
}

/* Optional column width control */
.Dump_Excel col {
	width: 80px;
}

.Dump_Excel-workbook {
	display: flex;
    border: 1px solid ##bfbfbf;
}

/* Sheet area */
.Dump_Excel-sheets {
	padding: 12px;
min-height: 300px;
}

.Dump_Excel-sheet {
	display: none;
}
.Dump_Excel-sheet.active {
    display: block;
}

/* Tab container */
.Dump_Excel-tabs-container {
	display: flex;
	align-items: flex-end;
	border-top: 1px solid ##bfbfbf;
	background: ##e6e6e6;
	padding: 4px 6px 0;
}

/* Individual tab */
.Dump_Excel_tab {
	padding: 6px 16px;
	margin-right: 4px;
	background: ##d9d9d9;
	border: 1px solid ##bfbfbf;
	border-bottom: none;
	cursor: pointer;
	font-family: Calibri, "Segoe UI", Arial, sans-serif;
	font-size: 13px;
	color: ##333;
	border-top-left-radius: 4px;
	border-top-right-radius: 4px;
}

.Dump_Excel_tab:hover {
	background: ##eeeeee;
}

/* Active tab */
.Dump_Excel_tab.active {
	background: ##ffffff;
	border-bottom: 1px solid ##ffffff;
	font-weight: 600;
}
</style>
');
}

private function OutputExcelJS() {
	// Excel CSS & Javascript generatd by ChatGPT and then altered for use
	if (StructKeyExists(Request,"cfdump_excel_js")) return;
	Request.cfdump_excel_js=true;
	writeoutput('
<script language="Javascript">
document.querySelectorAll(".Dump_Excel-tabs-container .Dump_Excel_tab").forEach(tab => {
    tab.addEventListener("click", () => {

        // Deactivate all tabs
        document.querySelectorAll(".Dump_Excel-tabs-container .Dump_Excel_tab")
            .forEach(t => t.classList.remove("active"));

        // Hide all sheets
        document.querySelectorAll(".Dump_Excel-sheet")
            .forEach(sheet => sheet.classList.remove("active"));

        // Activate selected tab
        tab.classList.add("active");

        // Show corresponding sheet
        const targetId = tab.getAttribute("data-target");
        document.getElementById(targetId).classList.add("active");
    });
});
</script>
');
}


private function OutputBinaryCSS() {
	if (StructKeyExists(Request,"cfdump_binary_css")) return;
	Request.cfdump_binary_css=true;
	writeoutput('
<style type="text/css">

.DumpBinaryOuterDiv {
	flex: 0 0 auto;
	display: flex;
	align-self: flex-start;
	align-items: flex-start;
	flex-direction: row;
	justify-content: flex-start;
}
 
.DumpBinaryHexDiv {
	width: 810px;
	display: flex;
	flex-wrap: wrap;
	align-items: flex-start;
	padding-right: 8px;
}
.DumpBinaryHexDivSmall {
	display: flex;
	flex-wrap: wrap;
	align-items: flex-start;
	padding-right: 8px;
}
 
.DumpBinaryOuterWrap {
	display: flex;
	align-items: flex-start;
	flex-direction: column;
}
 
.BinaryDataHex {
	flex: 0 0 auto;
	width: 160px;
	display: flex;
	font-size: 11px;
	align-items: flex-start;
	font-family: "Courier New";
	border-color: rgba(0, 0, 0, 0.5);
	border-width: 0px 1px 0px 0px;
	background-color: white;
}
.BinaryDataHexSmall {
	flex: 0 0 auto;
	display: flex;
	font-size: 11px;
	align-items: flex-start;
	font-family: "Courier New";
	border-color: rgba(0, 0, 0, 0.5);
	border-width: 0px 1px 0px 0px;
	background-color: white;
}
 
.BinaryDataASCII {
	flex: 0 0 auto;
	width: 53px;
	display: flex;
	font-size: 11px;
	align-items: flex-start;
	font-family: Courier New;
	border-color: rgba(0, 0, 0, 0.5);
	border-width: 0px 1px 0px 0px;
	background-color: white;
}
.BinaryDataASCIISmall {
	flex: 0 0 auto;
	display: flex;
	font-size: 11px;
	align-items: flex-start;
	font-family: Courier New;
	border-color: rgba(0, 0, 0, 0.5);
	border-width: 0px 1px 0px 0px;
	background-color: white;
}
 
.DumpBinaryASCIIDiv {
	width: 268px;
	display: flex;
	flex-wrap: wrap;
	align-items: flex-start;
}
.DumpBinaryASCIIDivSmall {
	display: flex;
	flex-wrap: wrap;
	align-items: flex-start;
}
</style>
');
}

// Output the CSS and Javascript generated by ColdFusion 2025 CFDUMP tag, encoded into Base64 to preserve # and single quotes
private function OutputDumpSupportCF() {
	if (StructKeyExists(Request,"cfdumpinited")) return;
	Request.cfdumpinited=true;
	writeoutput(ToString(ToBinary(
		"PHN0eWxlPgoKCgl0YWJsZS5jZmR1bXBfd2RkeCwKCXRhYmxlLmNmZHVtcF94bWwsCgl0YWJsZS5jZmR1bXBfc3RydWN0LAoJdGFibGUuY2ZkdW1wX3ZhcnVuZGVmaW5lZCwKCXRhYmxlLmNmZHVtcF9hcnJheSwK" &
		"CXRhYmxlLmNmZHVtcF9xdWVyeSwKCXRhYmxlLmNmZHVtcF9jZmMsCgl0YWJsZS5jZmR1bXBfb2JqZWN0LAoJdGFibGUuY2ZkdW1wX2JpbmFyeSwKCXRhYmxlLmNmZHVtcF91ZGYsCgl0YWJsZS5jZmR1bXBfdWRm" &
		"Ym9keSwKCXRhYmxlLmNmZHVtcF92YXJudWxsLAoJdGFibGUuY2ZkdW1wX3VkZmFyZ3VtZW50cyB7CgkJZm9udC1zaXplOiB4eC1zbWFsbDsKCQlmb250LWZhbWlseTogdmVyZGFuYSwgYXJpYWwsIGhlbHZldGlj" &
		"YSwgc2Fucy1zZXJpZjsKCX0KCgl0YWJsZS5jZmR1bXBfd2RkeCB0aCwKCXRhYmxlLmNmZHVtcF94bWwgdGgsCgl0YWJsZS5jZmR1bXBfc3RydWN0IHRoLAoJdGFibGUuY2ZkdW1wX3ZhcnVuZGVmaW5lZCB0aCwK" &
		"CXRhYmxlLmNmZHVtcF9hcnJheSB0aCwKCXRhYmxlLmNmZHVtcF9xdWVyeSB0aCwKCXRhYmxlLmNmZHVtcF9jZmMgdGgsCgl0YWJsZS5jZmR1bXBfb2JqZWN0IHRoLAoJdGFibGUuY2ZkdW1wX2JpbmFyeSB0aCwK" &
		"CXRhYmxlLmNmZHVtcF91ZGYgdGgsCgl0YWJsZS5jZmR1bXBfdWRmYm9keSB0aCwKCXRhYmxlLmNmZHVtcF92YXJudWxsIHRoLAoJdGFibGUuY2ZkdW1wX3VkZmFyZ3VtZW50cyB0aCB7CgkJdGV4dC1hbGlnbjog" &
		"bGVmdDsKCQljb2xvcjogd2hpdGU7CgkJcGFkZGluZzogNXB4OwoJfQoKCXRhYmxlLmNmZHVtcF93ZGR4IHRkLAoJdGFibGUuY2ZkdW1wX3htbCB0ZCwKCXRhYmxlLmNmZHVtcF9zdHJ1Y3QgdGQsCgl0YWJsZS5j" &
		"ZmR1bXBfdmFydW5kZWZpbmVkIHRkLAoJdGFibGUuY2ZkdW1wX2FycmF5IHRkLAoJdGFibGUuY2ZkdW1wX3F1ZXJ5IHRkLAoJdGFibGUuY2ZkdW1wX2NmYyB0ZCwKCXRhYmxlLmNmZHVtcF9vYmplY3QgdGQsCgl0" &
		"YWJsZS5jZmR1bXBfYmluYXJ5IHRkLAoJdGFibGUuY2ZkdW1wX3VkZiB0ZCwKCXRhYmxlLmNmZHVtcF91ZGZib2R5IHRkLAoJdGFibGUuY2ZkdW1wX3Zhcm51bGwgdGQsCgl0YWJsZS5jZmR1bXBfdWRmYXJndW1l" &
		"bnRzIHRkIHsKCQlwYWRkaW5nOiAzcHg7CgkJYmFja2dyb3VuZC1jb2xvcjogI2ZmZmZmZjsKCQl2ZXJ0aWNhbC1hbGlnbiA6IHRvcDsKCX0KCgl0YWJsZS5jZmR1bXBfd2RkeCB7CgkJYmFja2dyb3VuZC1jb2xv" &
		"cjogIzAwMDAwMDsKCX0KCXRhYmxlLmNmZHVtcF93ZGR4IHRoLndkZHggewoJCWJhY2tncm91bmQtY29sb3I6ICM0NDQ0NDQ7Cgl9CgoKCXRhYmxlLmNmZHVtcF94bWwgewoJCWJhY2tncm91bmQtY29sb3I6ICM4" &
		"ODg4ODg7Cgl9Cgl0YWJsZS5jZmR1bXBfeG1sIHRoLnhtbCB7CgkJYmFja2dyb3VuZC1jb2xvcjogI2FhYWFhYTsKCX0KCXRhYmxlLmNmZHVtcF94bWwgdGQueG1sIHsKCQliYWNrZ3JvdW5kLWNvbG9yOiAjZGRk" &
		"ZGRkOwoJfQoKCXRhYmxlLmNmZHVtcF9zdHJ1Y3QgewoJCWJhY2tncm91bmQtY29sb3I6ICMwMDAwY2MgOwoJfQoJdGFibGUuY2ZkdW1wX3N0cnVjdCB0aC5zdHJ1Y3QgewoJCWJhY2tncm91bmQtY29sb3I6ICM0" &
		"NDQ0Y2MgOwoJfQoJdGFibGUuY2ZkdW1wX3N0cnVjdCB0ZC5zdHJ1Y3QgewoJCWJhY2tncm91bmQtY29sb3I6ICNjY2RkZmY7Cgl9CgoJdGFibGUuY2ZkdW1wX3ZhcnVuZGVmaW5lZCB7CgkJYmFja2dyb3VuZC1j" &
		"b2xvcjogI0NDMzMwMCA7Cgl9Cgl0YWJsZS5jZmR1bXBfdmFydW5kZWZpbmVkIHRoLnZhcnVuZGVmaW5lZCB7CgkJYmFja2dyb3VuZC1jb2xvcjogI0NDMzMwMCA7Cgl9Cgl0YWJsZS5jZmR1bXBfdmFydW5kZWZp" &
		"bmVkIHRkLnZhcnVuZGVmaW5lZCB7CgkJYmFja2dyb3VuZC1jb2xvcjogI2NjZGRmZjsKCX0KCgl0YWJsZS5jZmR1bXBfYXJyYXkgewoJCWJhY2tncm91bmQtY29sb3I6ICMwMDY2MDAgOwoJfQoJdGFibGUuY2Zk" &
		"dW1wX2FycmF5IHRoLmFycmF5IHsKCQliYWNrZ3JvdW5kLWNvbG9yOiAjMDA5OTAwIDsKCX0KCXRhYmxlLmNmZHVtcF9hcnJheSB0ZC5hcnJheSB7CgkJYmFja2dyb3VuZC1jb2xvcjogI2NjZmZjYyA7Cgl9CgoJ" &
		"dGFibGUuY2ZkdW1wX3F1ZXJ5IHsKCQliYWNrZ3JvdW5kLWNvbG9yOiAjODg0NDg4IDsKCX0KCXRhYmxlLmNmZHVtcF9xdWVyeSB0aC5xdWVyeSB7CgkJYmFja2dyb3VuZC1jb2xvcjogI2FhNjZhYSA7Cgl9Cgl0" &
		"YWJsZS5jZmR1bXBfcXVlcnkgdGQucXVlcnkgewoJCWJhY2tncm91bmQtY29sb3I6ICNmZmRkZmYgOwoJfQoKCgl0YWJsZS5jZmR1bXBfY2ZjIHsKCQliYWNrZ3JvdW5kLWNvbG9yOiAjZmYwMDAwOwoJfQoJdGFi" &
		"bGUuY2ZkdW1wX2NmYyB0aC5jZmN7CgkJYmFja2dyb3VuZC1jb2xvcjogI2ZmNDQ0NDsKCX0KCXRhYmxlLmNmZHVtcF9jZmMgdGQuY2ZjIHsKCQliYWNrZ3JvdW5kLWNvbG9yOiAjZmZjY2NjOwoJfQoKCgl0YWJs" &
		"ZS5jZmR1bXBfb2JqZWN0IHsKCQliYWNrZ3JvdW5kLWNvbG9yIDogI2ZmMDAwMDsKCX0KCXRhYmxlLmNmZHVtcF9vYmplY3QgdGgub2JqZWN0ewoJCWJhY2tncm91bmQtY29sb3I6ICNmZjQ0NDQ7Cgl9CgoJdGFi" &
		"bGUuY2ZkdW1wX2JpbmFyeSB7CgkJYmFja2dyb3VuZC1jb2xvciA6ICNlZWJiMDA7Cgl9Cgl0YWJsZS5jZmR1bXBfYmluYXJ5IHRoLmJpbmFyeSB7CgkJYmFja2dyb3VuZC1jb2xvcjogI2ZmY2M0NDsKCX0KCXRh" &
		"YmxlLmNmZHVtcF9iaW5hcnkgdGQgewoJCWZvbnQtc2l6ZTogeC1zbWFsbDsKCX0KCXRhYmxlLmNmZHVtcF91ZGYgewoJCWJhY2tncm91bmQtY29sb3I6ICNhYTQ0MDA7Cgl9Cgl0YWJsZS5jZmR1bXBfdWRmIHRo" &
		"LnVkZiB7CgkJYmFja2dyb3VuZC1jb2xvcjogI2NjNjYwMDsKCX0KCXRhYmxlLmNmZHVtcF91ZGZhcmd1bWVudHMgewoJCWJhY2tncm91bmQtY29sb3I6ICNkZGRkZGQ7Cgl9Cgl0YWJsZS5jZmR1bXBfdWRmYXJn" &
		"dW1lbnRzIHRoIHsKCQliYWNrZ3JvdW5kLWNvbG9yOiAjZWVlZWVlOwoJCWNvbG9yOiAjMDAwMDAwOwoJfQoKPC9zdHlsZT4gPHNjcmlwdCBsYW5ndWFnZT0iamF2YXNjcmlwdCIgbm9uY2U9Im51bGwiPgoKCi8v" &
		"IGZvciBxdWVyaWVzIHdlIGhhdmUgbW9yZSB0aGFuIG9uZSB0ZCBlbGVtZW50IHRvIGNvbGxhcHNlL2V4cGFuZAoJdmFyIGV4cGFuZCA9ICJvcGVuIjsKCglkdW1wID0gZnVuY3Rpb24oIG9iaiApIHsKCQl2YXIg" &
		"b3V0ID0gIiIgOwoJCWlmICggdHlwZW9mIG9iaiA9PSAib2JqZWN0IiApIHsKCQkJZm9yICgga2V5IGluIG9iaiApIHsKCQkJCWlmICggdHlwZW9mIG9ialtrZXldICE9ICJmdW5jdGlvbiIgKSBvdXQgKz0ga2V5" &
		"ICsgJzogJyArIG9ialtrZXldICsgJzxicj4nIDsKCQkJfQoJCX0KCX0KCgoJY2ZkdW1wX3RvZ2dsZVJvdyA9IGZ1bmN0aW9uKHNvdXJjZSkgewoJCS8vdGFyZ2V0IGlzIHRoZSByaWdodCBjZWxsCgkJaWYoZG9j" &
		"dW1lbnQuYWxsKSB0YXJnZXQgPSBzb3VyY2UucGFyZW50RWxlbWVudC5jZWxsc1sxXTsKCQllbHNlIHsKCQkJdmFyIGVsZW1lbnQgPSBudWxsOwoJCQl2YXIgdkxlbiA9IHNvdXJjZS5wYXJlbnROb2RlLmNoaWxk" &
		"Tm9kZXMubGVuZ3RoOwoJCQlmb3IodmFyIGk9dkxlbi0xO2k+MDtpLS0pewoJCQkJaWYoc291cmNlLnBhcmVudE5vZGUuY2hpbGROb2Rlc1tpXS5ub2RlVHlwZSA9PSAxKXsKCQkJCQllbGVtZW50ID0gc291cmNl" &
		"LnBhcmVudE5vZGUuY2hpbGROb2Rlc1tpXTsKCQkJCQlicmVhazsKCQkJCX0KCQkJfQoJCQlpZihlbGVtZW50ID09IG51bGwpCgkJCQl0YXJnZXQgPSBzb3VyY2UucGFyZW50Tm9kZS5sYXN0Q2hpbGQ7CgkJCWVs" &
		"c2UKCQkJCXRhcmdldCA9IGVsZW1lbnQ7CgkJfQoJCS8vdGFyZ2V0ID0gc291cmNlLnBhcmVudE5vZGUubGFzdENoaWxkIDsKCQljZmR1bXBfdG9nZ2xlVGFyZ2V0KCB0YXJnZXQsIGNmZHVtcF90b2dnbGVTb3Vy" &
		"Y2UoIHNvdXJjZSApICkgOwoJfQoKCWNmZHVtcF90b2dnbGVYbWxEb2MgPSBmdW5jdGlvbihzb3VyY2UpIHsKCgkJdmFyIGNhcHRpb24gPSBzb3VyY2UuaW5uZXJIVE1MLnNwbGl0KCAnIFsnICkgOwoKCQkvLyB0" &
		"b2dnbGUgc291cmNlIChoZWFkZXIpCgkJaWYgKCBzb3VyY2Uuc3R5bGUuZm9udFN0eWxlID09ICdpdGFsaWMnICkgewoJCQkvLyBjbG9zZWQgLT4gc2hvcnQKCQkJc291cmNlLnN0eWxlLmZvbnRTdHlsZSA9ICdu" &
		"b3JtYWwnIDsKCQkJc291cmNlLmlubmVySFRNTCA9IGNhcHRpb25bMF0gKyAnIFtzaG9ydCB2ZXJzaW9uXScgOwoJCQlzb3VyY2UudGl0bGUgPSAnY2xpY2sgdG8gbWF4aW1pemUnIDsKCQkJc3dpdGNoTG9uZ1Rv" &
		"U3RhdGUgPSAnY2xvc2VkJyA7CgkJCXN3aXRjaFNob3J0VG9TdGF0ZSA9ICdvcGVuJyA7CgkJfSBlbHNlIGlmICggc291cmNlLmlubmVySFRNTC5pbmRleE9mKCdbc2hvcnQgdmVyc2lvbl0nKSAhPSAtMSApIHsK" &
		"CQkJLy8gc2hvcnQgLT4gZnVsbAoJCQlzb3VyY2UuaW5uZXJIVE1MID0gY2FwdGlvblswXSArICcgW2xvbmcgdmVyc2lvbl0nIDsKCQkJc291cmNlLnRpdGxlID0gJ2NsaWNrIHRvIGNvbGxhcHNlJyA7CgkJCXN3" &
		"aXRjaExvbmdUb1N0YXRlID0gJ29wZW4nIDsKCQkJc3dpdGNoU2hvcnRUb1N0YXRlID0gJ2Nsb3NlZCcgOwoJCX0gZWxzZSB7CgkJCS8vIGZ1bGwgLT4gY2xvc2VkCgkJCXNvdXJjZS5zdHlsZS5mb250U3R5bGUg" &
		"PSAnaXRhbGljJyA7CgkJCXNvdXJjZS50aXRsZSA9ICdjbGljayB0byBleHBhbmQnIDsKCQkJc291cmNlLmlubmVySFRNTCA9IGNhcHRpb25bMF0gOwoJCQlzd2l0Y2hMb25nVG9TdGF0ZSA9ICdjbG9zZWQnIDsK" &
		"CQkJc3dpdGNoU2hvcnRUb1N0YXRlID0gJ2Nsb3NlZCcgOwoJCX0KCgkJLy8gVG9nZ2xlIHRoZSB0YXJnZXQgKGV2ZXJldGhpbmcgYmVsb3cgdGhlIGhlYWRlciByb3cpLgoJCS8vIEZpcnN0IHR3byByb3dzIGFy" &
		"ZSBYTUxDb21tZW50IGFuZCBYTUxSb290IC0gdGhleSBhcmUgcGFydAoJCS8vIG9mIHRoZSBsb25nIGR1bXAsIHRoZSByZXN0IGFyZSBkaXJlY3QgY2hpbGRyZW4gLSBwYXJ0IG9mIHRoZQoJCS8vIHNob3J0IGR1" &
		"bXAKCQlpZihkb2N1bWVudC5hbGwpIHsKCQkJdmFyIHRhYmxlID0gc291cmNlLnBhcmVudEVsZW1lbnQucGFyZW50RWxlbWVudCA7CgkJCWZvciAoIHZhciBpID0gMTsgaSA8IHRhYmxlLnJvd3MubGVuZ3RoOyBp" &
		"KysgKSB7CgkJCQl0YXJnZXQgPSB0YWJsZS5yb3dzW2ldIDsKCQkJCWlmICggaSA8IDMgKSBjZmR1bXBfdG9nZ2xlVGFyZ2V0KCB0YXJnZXQsIHN3aXRjaExvbmdUb1N0YXRlICkgOwoJCQkJZWxzZSBjZmR1bXBf" &
		"dG9nZ2xlVGFyZ2V0KCB0YXJnZXQsIHN3aXRjaFNob3J0VG9TdGF0ZSApIDsKCQkJfQoJCX0KCQllbHNlIHsKCQkJdmFyIHRhYmxlID0gc291cmNlLnBhcmVudE5vZGUucGFyZW50Tm9kZSA7CgkJCXZhciByb3cg" &
		"PSAxOwoJCQlmb3IgKCB2YXIgaSA9IDE7IGkgPCB0YWJsZS5jaGlsZE5vZGVzLmxlbmd0aDsgaSsrICkgewoJCQkJdGFyZ2V0ID0gdGFibGUuY2hpbGROb2Rlc1tpXSA7CgkJCQlpZiggdGFyZ2V0LnN0eWxlICkg" &
		"ewoJCQkJCWlmICggcm93IDwgMyApIHsKCQkJCQkJY2ZkdW1wX3RvZ2dsZVRhcmdldCggdGFyZ2V0LCBzd2l0Y2hMb25nVG9TdGF0ZSApIDsKCQkJCQl9IGVsc2UgewoJCQkJCQljZmR1bXBfdG9nZ2xlVGFyZ2V0" &
		"KCB0YXJnZXQsIHN3aXRjaFNob3J0VG9TdGF0ZSApIDsKCQkJCQl9CgkJCQkJcm93Kys7CgkJCQl9CgkJCX0KCQl9Cgl9CgoJY2ZkdW1wX3RvZ2dsZVRhYmxlID0gZnVuY3Rpb24oc291cmNlKSB7CgoJCXZhciBz" &
		"d2l0Y2hUb1N0YXRlID0gY2ZkdW1wX3RvZ2dsZVNvdXJjZSggc291cmNlICkgOwoJCWlmKGRvY3VtZW50LmFsbCkgewoJCQl2YXIgdGFibGUgPSBzb3VyY2UucGFyZW50RWxlbWVudC5wYXJlbnRFbGVtZW50IDsK" &
		"CQkJZm9yICggdmFyIGkgPSAxOyBpIDwgdGFibGUucm93cy5sZW5ndGg7IGkrKyApIHsKCQkJCXRhcmdldCA9IHRhYmxlLnJvd3NbaV0gOwoJCQkJY2ZkdW1wX3RvZ2dsZVRhcmdldCggdGFyZ2V0LCBzd2l0Y2hU" &
		"b1N0YXRlICkgOwoJCQl9CgkJfQoJCWVsc2UgewoJCQl2YXIgdGFibGUgPSBzb3VyY2UucGFyZW50Tm9kZS5wYXJlbnROb2RlIDsKCQkJZm9yICggdmFyIGkgPSAxOyBpIDwgdGFibGUuY2hpbGROb2Rlcy5sZW5n" &
		"dGg7IGkrKyApIHsKCQkJCXRhcmdldCA9IHRhYmxlLmNoaWxkTm9kZXNbaV0gOwoJCQkJaWYodGFyZ2V0LnN0eWxlKSB7CgkJCQkJY2ZkdW1wX3RvZ2dsZVRhcmdldCggdGFyZ2V0LCBzd2l0Y2hUb1N0YXRlICkg" &
		"OwoJCQkJfQoJCQl9CgkJfQoJfQoKCWNmZHVtcF90b2dnbGVTb3VyY2UgPSBmdW5jdGlvbiggc291cmNlICkgewoJCWlmICggc291cmNlLnN0eWxlLmZvbnRTdHlsZSA9PSAnaXRhbGljJyB8fCBzb3VyY2Uuc3R5" &
		"bGUuZm9udFN0eWxlID09IG51bGwpIHsKCQkJc291cmNlLnN0eWxlLmZvbnRTdHlsZSA9ICdub3JtYWwnIDsKCQkJc291cmNlLnRpdGxlID0gJ2NsaWNrIHRvIGNvbGxhcHNlJyA7CgkJCXJldHVybiAnb3Blbicg" &
		"OwoJCX0gZWxzZSB7CgkJCXNvdXJjZS5zdHlsZS5mb250U3R5bGUgPSAnaXRhbGljJyA7CgkJCXNvdXJjZS50aXRsZSA9ICdjbGljayB0byBleHBhbmQnIDsKCQkJcmV0dXJuICdjbG9zZWQnIDsKCQl9Cgl9CgoJ" &
		"Y2ZkdW1wX3RvZ2dsZVRhcmdldCA9IGZ1bmN0aW9uKCB0YXJnZXQsIHN3aXRjaFRvU3RhdGUgKSB7CgkJaWYgKCBzd2l0Y2hUb1N0YXRlID09ICdvcGVuJyApCXRhcmdldC5zdHlsZS5kaXNwbGF5ID0gJycgOwoJ" &
		"CWVsc2UgdGFyZ2V0LnN0eWxlLmRpc3BsYXkgPSAnbm9uZScgOwoJfQoKCS8vIGNvbGxhcHNlIGFsbCB0ZCBlbGVtZW50cyBmb3IgcXVlcmllcwoJY2ZkdW1wX3RvZ2dsZVJvd19xcnkgPSBmdW5jdGlvbihzb3Vy" &
		"Y2UpIHsKCQlleHBhbmQgPSAoc291cmNlLnRpdGxlID09ICJjbGljayB0byBjb2xsYXBzZSIpID8gImNsb3NlZCIgOiAib3BlbiI7CgkJaWYoZG9jdW1lbnQuYWxsKSB7CgkJCXZhciBuYnJDaGlsZHJlbiA9IHNv" &
		"dXJjZS5wYXJlbnRFbGVtZW50LmNlbGxzLmxlbmd0aDsKCQkJaWYobmJyQ2hpbGRyZW4gPiAxKXsKCQkJCWZvcihpPW5ickNoaWxkcmVuLTE7aT4wO2ktLSl7CgkJCQkJdGFyZ2V0ID0gc291cmNlLnBhcmVudEVs" &
		"ZW1lbnQuY2VsbHNbaV07CgkJCQkJY2ZkdW1wX3RvZ2dsZVRhcmdldCggdGFyZ2V0LGV4cGFuZCApIDsKCQkJCQljZmR1bXBfdG9nZ2xlU291cmNlX3FyeShzb3VyY2UpOwoJCQkJfQoJCQl9CgkJCWVsc2UgewoJ" &
		"CQkJLy90YXJnZXQgaXMgdGhlIHJpZ2h0IGNlbGwKCQkJCXRhcmdldCA9IHNvdXJjZS5wYXJlbnRFbGVtZW50LmNlbGxzWzFdOwoJCQkJY2ZkdW1wX3RvZ2dsZVRhcmdldCggdGFyZ2V0LCBjZmR1bXBfdG9nZ2xl" &
		"U291cmNlKCBzb3VyY2UgKSApIDsKCQkJfQoJCX0KCQllbHNlewoJCQl2YXIgdGFyZ2V0ID0gbnVsbDsKCQkJdmFyIHZMZW4gPSBzb3VyY2UucGFyZW50Tm9kZS5jaGlsZE5vZGVzLmxlbmd0aDsKCQkJZm9yKHZh" &
		"ciBpPXZMZW4tMTtpPjE7aS0tKXsKCQkJCWlmKHNvdXJjZS5wYXJlbnROb2RlLmNoaWxkTm9kZXNbaV0ubm9kZVR5cGUgPT0gMSl7CgkJCQkJdGFyZ2V0ID0gc291cmNlLnBhcmVudE5vZGUuY2hpbGROb2Rlc1tp" &
		"XTsKCQkJCQljZmR1bXBfdG9nZ2xlVGFyZ2V0KCB0YXJnZXQsZXhwYW5kICk7CgkJCQkJY2ZkdW1wX3RvZ2dsZVNvdXJjZV9xcnkoc291cmNlKTsKCQkJCX0KCQkJfQoJCQlpZih0YXJnZXQgPT0gbnVsbCl7CgkJ" &
		"CQkvL3RhcmdldCBpcyB0aGUgbGFzdCBjZWxsCgkJCQl0YXJnZXQgPSBzb3VyY2UucGFyZW50Tm9kZS5sYXN0Q2hpbGQ7CgkJCQljZmR1bXBfdG9nZ2xlVGFyZ2V0KCB0YXJnZXQsIGNmZHVtcF90b2dnbGVTb3Vy" &
		"Y2UoIHNvdXJjZSApICkgOwoJCQl9CgkJfQoJfQoKCWNmZHVtcF90b2dnbGVTb3VyY2VfcXJ5ID0gZnVuY3Rpb24oc291cmNlKSB7CgkJaWYoZXhwYW5kID09ICJjbG9zZWQiKXsKCQkJc291cmNlLnRpdGxlID0g" &
		"ImNsaWNrIHRvIGV4cGFuZCI7CgkJCXNvdXJjZS5zdHlsZS5mb250U3R5bGUgPSAiaXRhbGljIjsKCQl9CgkJZWxzZXsKCQkJc291cmNlLnRpdGxlID0gImNsaWNrIHRvIGNvbGxhcHNlIjsKCQkJc291cmNlLnN0" &
		"eWxlLmZvbnRTdHlsZSA9ICJub3JtYWwiOwoJCX0KCX0KCjwvc2NyaXB0PiA=")) & Chr(10)
	);
}

</cfscript>

