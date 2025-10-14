/*

  SumatraPDF.prg
  Library functions for handling SumatraPDF reader in plugin mode
  Version: 2020-04-09
  Author:  KDJ

  Designed for SumatraPDF ver. 3.1.2 and 3.2
  https://www.sumatrapdfreader.org

  Compile to library libSumatraPDF.a or include SumatraPDF.prg into your project
  
  Contains functions:
    *Harbour
    Sumatra_FileOpen
    Sumatra_FileClose
    Sumatra_FileName
    Sumatra_FileSaveAs
    Sumatra_FilePrint
    Sumatra_FilePrintDirectly
    Sumatra_FileProperties
    Sumatra_FrameHandle
    Sumatra_FrameAdjust
    Sumatra_FrameRedraw
    Sumatra_Bookmarks
    Sumatra_BookmarksHandle
    Sumatra_BookmarksExist
    Sumatra_BookmarksExpand
    Sumatra_Toolbar
    Sumatra_ToolbarHandle
    Sumatra_PageGoTo
    Sumatra_PageNumber
    Sumatra_PageCount
    Sumatra_FindText
    Sumatra_SelectAll
    Sumatra_GetSelText
    Sumatra_Zoom
    Sumatra_Rotate
    Sumatra_View
    Sumatra_About
    Sumatra_Version
    Sumatra_Command
    *C
    GetFileVersion
    GetWindowText2

*/


#include "hmg.ch"
#include "hbver.ch"
#include "SumatraPDF.ch"


/*
  Sumatra_FileOpen(cPanel, cPdfFile, [nPage], [nZoom], [nView], [lBookmarks], [lToolbar], [cLanguage], [cSumatraPDFExe])
    nZoom can be:
      2 - fit page
      3 - actual (real) size
      4 - fit width (default)
  --> >0 - if no error, page number of cPdfFile is returned
  -->  0 - if error loading cPdfFile occurs
  --> -1 - if cPanel window is not defined
  --> -2 - if SumatraPDF.exe not found
  --> -3 - if cPdfFile does not exist
  --> -4 - if SumatraPDF is not valid version
  --> -5 - if Harbour is 32-bit and SumatraPDF is 64-bit
*/
FUNCTION Sumatra_FileOpen(cPanel, cPdfFile, nPage, nZoom, nView, lBookmarks, lToolbar, cLang, cExeFile)
  LOCAL aVersion
  LOCAL nHFrame
  LOCAL cZoom
  LOCAL cView

  IF ! _IsWindowDefined(cPanel)
    RETURN -1
  ENDIF

  IF (! HB_IsChar(cExeFile)) .or. Empty(cExeFile)
    cExeFile := HB_DirBase() + "SumatraPDF.exe"
  ENDIF

  IF ! HB_FileExists(cExeFile)
    RETURN -2
  ENDIF

  IF (! HB_IsChar(cPdfFile)) .or. (VolSerial(HB_ULeft(cPdfFile, 3)) == -1) .or. (! HB_FileExists(cPdfFile))
    RETURN -3
  ENDIF

  aVersion := Sumatra_Version(NIL, cExeFile)

  IF (! HB_IsArray(aVersion)) .or. ;
     (aVersion[1] != 3) .or. ;
     (! ((aVersion[2] == 1) .and. (aVersion[3] == 2) .or. (aVersion[2] == 2) .and. (aVersion[3] == 0)))
    RETURN -4
  ENDIF

  IF (HB_Version(HB_VERSION_BITWIDTH) == 32) .and. (GetBinaryType(cExeFile) == 6 /*SCS_64BIT_BINARY*/)
    RETURN -5
  ENDIF

  IF (! HB_IsNumeric(nPage)) .or. (nPage < 1)
    nPage := 1
  ENDIF

  HB_Default(@nZoom, 4)
  HB_Default(@nView, 1)
  HB_Default(@cLang, "en")

  SWITCH nZoom
    CASE 2    ; cZoom := '"fit page"'    ; EXIT
    CASE 3    ; cZoom := '"actual size"' ; EXIT
    OTHERWISE ; cZoom := '"fit width"'
  ENDSWITCH

  SWITCH nView
    CASE 2    ; cView := '"continuous facing"'    ; EXIT
    CASE 3    ; cView := '"continuous book view"' ; EXIT
    OTHERWISE ; cView := '"continuous single page"'
  ENDSWITCH

  IF Sumatra_FrameHandle(cPanel) != 0
    Sumatra_FileClose(cPanel)
  ENDIF

  ShellExecute(0, 'open', cExeFile, '-page ' + HB_NtoS(nPage) + ' -lang ' + cLang + ' -zoom ' + cZoom + ' -view ' + cView + ' -plugin ' +  HB_NtoS(GetFormHandle(cPanel)) + ' "' + cPdfFile + '"', NIL, 10 /*SW_SHOWDEFAULT*/)

  DO WHILE ((nHFrame := Sumatra_FrameHandle(cPanel)) == 0) .or. (Sumatra_ToolbarHandle(cPanel) == 0) .or. (Sumatra_BookmarksHandle(cPanel) == 0)
    HB_IdleSleep(0.01)
  ENDDO

  Sumatra_Toolbar(cPanel, lToolbar)
  SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_VIEW_BOOKMARKS), 0)
  Sumatra_Bookmarks(cPanel, lBookmarks)

  IF nPage > Sumatra_PageCount(cPanel)
    Sumatra_PageGoTo(cPanel, 2 /*last page*/)
  ENDIF

  SetWindowText(nHFrame, cPdfFile)

RETURN Sumatra_PageNumber(cPanel)


FUNCTION Sumatra_FileClose(cPanel, lRedraw)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nHPanel
  LOCAL nPID

  IF nHFrame != 0
    nHPanel := GetFormHandle(cPanel)
    EnableWindowRedraw(nHPanel, .F.)

    GetWindowThreadProcessId(nHFrame, NIL, @nPID)
    TerminateProcess(nPID)

    DO WHILE IsValidWindowHandle(nHFrame)
    ENDDO

    EnableWindowRedraw(nHPanel, .T., lRedraw)
  ENDIF

RETURN NIL


       //Sumatra_FileName(cPanel) --> name of opened PDF file or empty string
FUNCTION Sumatra_FileName(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    RETURN GetWindowText(nHFrame)
  ENDIF

RETURN ""


FUNCTION Sumatra_FileSaveAs(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    PostMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_SAVEAS), 0)
  ENDIF

RETURN NIL


FUNCTION Sumatra_FilePrint(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    PostMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_PRINT), 0)
  ENDIF

RETURN NIL


/*
  Sumatra_FilePrintDirectly(cPdfFile, [cLanguage], [cSumatraPDFExe])
    return:
       1 - if no error
      -2 - if SumatraPDF.exe not found
      -3 - if cPdfFile does not exist
      -4 - if SumatraPDF is not valid version
      -5 - if Harbour is 32-bit and SumatraPDF is 64-bit
*/
FUNCTION Sumatra_FilePrintDirectly(cPdfFile, cLang, cExeFile)
  LOCAL aVersion

  IF (! HB_IsChar(cExeFile)) .or. Empty(cExeFile)
    cExeFile := HB_DirBase() + "SumatraPDF.exe"
  ENDIF

  IF ! HB_FileExists(cExeFile)
    RETURN -2
  ENDIF

  IF (! HB_IsChar(cPdfFile)) .or. (VolSerial(HB_ULeft(cPdfFile, 3)) == -1) .or. (! HB_FileExists(cPdfFile))
    RETURN -3
  ENDIF

  aVersion := Sumatra_Version(NIL, cExeFile)

  IF (! HB_IsArray(aVersion)) .or. ;
     (aVersion[1] != 3) .or. ;
     (! ((aVersion[2] == 1) .and. (aVersion[3] == 2) .or. (aVersion[2] == 2) .and. (aVersion[3] == 0)))
    RETURN -4
  ENDIF

  IF (HB_Version(HB_VERSION_BITWIDTH) == 32) .and. (GetBinaryType(cExeFile) == 6 /*SCS_64BIT_BINARY*/)
    RETURN -5
  ENDIF

  HB_Default(@cLang, "en")

  ShellExecute(0, 'open', cExeFile, '-print-dialog -exit-when-done -lang ' + cLang + ' "' + cPdfFile + '"', NIL, 0 /*SW_HIDE */)

RETURN 1


FUNCTION Sumatra_FileProperties(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    PostMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_PROPERTIES), 0)
  ENDIF

RETURN NIL


       //Sumatra_FrameHandle(cPanel) --> handle to Sumatra frame embeded in panel or 0 if no frame
FUNCTION Sumatra_FrameHandle(cPanel)

  IF _IsWindowDefined(cPanel)
    RETURN FindWindowEx(GetFormHandle(cPanel), 0, "SUMATRA_PDF_FRAME", 0)
  ENDIF

RETURN 0


FUNCTION Sumatra_FrameAdjust(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    SetWindowPos(nHFrame, 0, 0, 0, GetProperty(cPanel, "CLIENTAREAWIDTH"), GetProperty(cPanel, "CLIENTAREAHEIGHT"), 0x0016 /*SWP_NOACTIVATE|SWP_NOZORDER|SWP_NOMOVE*/)
  ENDIF

RETURN NIL


FUNCTION Sumatra_FrameRedraw(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    RedrawWindow(nHFrame)
  ENDIF

RETURN NIL


       //Sumatra_Bookmarks(cPanel, [lShow]) - show/hide Sumatra bookmarks
       //--> previous setting
FUNCTION Sumatra_Bookmarks(cPanel, lShow)
  LOCAL lVisible := .F.
  LOCAL nHFrame  := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    lVisible := IsWindowVisible(Sumatra_BookmarksHandle(cPanel))

    IF HB_IsLogical(lShow)
      IF (lShow != lVisible) .and. Sumatra_BookmarksExist(cPanel)
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_VIEW_BOOKMARKS), 0)
      ENDIF
    ENDIF
  ENDIF

RETURN lVisible


       //Sumatra_BookmarksHandle(cPanel) --> handle to Sumatra bookmarks tree
FUNCTION Sumatra_BookmarksHandle(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL aHWnd
  LOCAL n

  IF nHFrame != 0
    aHWnd := EnumChildWindows(nHFrame)

    FOR n := 1 TO Len(aHWnd)
//      IF (GetClassName(aHWnd[n]) == "SysTreeView32") .and. (GetWindowText2(aHWnd[n]) == "TOC")
      IF (GetClassName(aHWnd[n]) == "SysTreeView32") .and. (! HMG_IsWindowStyle(aHWnd[n], 4 /*WS_EX_NOPARENTNOTIFY*/, .T.))
        RETURN aHWnd[n]
      ENDIF
    NEXT
  ENDIF

RETURN 0


FUNCTION Sumatra_BookmarksExist(cPanel)
  LOCAL lExist := .F.
  LOCAL nHBook := Sumatra_BookmarksHandle(cPanel)

  IF nHBook != 0
    lExist := (SendMessage(nHBook, 4357 /*TVM_GETCOUNT*/, 0, 0) != 0)
  ENDIF

RETURN lExist


       //Sumatra_BookmarksExpand(cPanel, lExpand) - expand or collapse all items in bookmarks tree
FUNCTION Sumatra_BookmarksExpand(cPanel, lExpand)
  LOCAL nHBook := Sumatra_BookmarksHandle(cPanel)
  LOCAL nHItem
  LOCAL nExpand

  IF IsWindowVisible(nHBook)
    nHItem  := TreeView_GetRoot(nHBook)
    nExpand := If(lExpand, 2 /*TVE_EXPAND*/, 1 /*TVE_COLLAPSE*/)

    DO WHILE nHItem != 0
      TreeView_ExpandChildrenRecursive(nHBook, nHItem, nExpand, .T.)
      nHItem := TreeView_GetNextSibling(nHBook, nHItem)
    ENDDO

    SendMessage(nHBook, 4372 /*TVM_ENSUREVISIBLE*/, 0, TreeView_GetSelection(nHBook))
  ENDIF

RETURN NIL


       //Sumatra_Toolbar(cPanel, [lShow]) - show/hide Sumatra toolbar
       //--> previous setting
FUNCTION Sumatra_Toolbar(cPanel, lShow)
  LOCAL lVisible := .F.
  LOCAL nHFrame  := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    lVisible := IsWindowVisible(Sumatra_ToolbarHandle(cPanel))

    IF HB_IsLogical(lShow)
      IF lShow != lVisible
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_VIEW_SHOW_HIDE_TOOLBAR), 0)
      ENDIF
    ENDIF
  ENDIF

RETURN lVisible


       //Sumatra_ToolbarHandle(cPanel) --> handle to Sumatra toolbar
FUNCTION Sumatra_ToolbarHandle(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nHReBar

  IF nHFrame != 0
    nHReBar := FindWindowEx(nHFrame, 0, "ReBarWindow32", 0)

    IF nHReBar != 0
      RETURN FindWindowEx(nHReBar, 0, "ToolbarWindow32", 0)
    ENDIF
  ENDIF

RETURN 0


/*
  nAction:
  -1 - go to previous page
   1 - go to next page
  -2 - go to first page
   2 - go to last page
  otherwise - "Go to" dialog
*/
FUNCTION Sumatra_PageGoTo(cPanel, nAction)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nWParam

  IF nHFrame != 0
    HB_Default(@nAction, 0)

    SWITCH nAction
      CASE -1   ; nWParam := Sumatra_Command(cPanel, IDM_GOTO_PREV_PAGE)  ; EXIT
      CASE  1   ; nWParam := Sumatra_Command(cPanel, IDM_GOTO_NEXT_PAGE)  ; EXIT
      CASE -2   ; nWParam := Sumatra_Command(cPanel, IDM_GOTO_FIRST_PAGE) ; EXIT
      CASE  2   ; nWParam := Sumatra_Command(cPanel, IDM_GOTO_LAST_PAGE)  ; EXIT
      OTHERWISE ; nWParam := Sumatra_Command(cPanel, IDM_GOTO_PAGE)
    ENDSWITCH

    PostMessage(nHFrame, 273 /*WM_COMMAND*/, nWParam, 0)
  ENDIF

RETURN NIL


/*
  Get current PDF page number
  Returns 0 if error loading occurs
*/
FUNCTION Sumatra_PageNumber(cPanel)
  LOCAL nPage   := 0
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nHReBar
  LOCAL aHWnd

  LOCAL cText
  LOCAL nPos
  LOCAL n

  IF nHFrame != 0
    nHReBar := FindWindowEx(nHFrame, 0, "ReBarWindow32", 0)

    IF nHReBar != 0
      aHWnd := EnumChildWindows(nHReBar)

      FOR n := 1 TO Len(aHWnd)
        IF (GetClassName(aHWnd[n]) == "Static")
          cText := GetWindowText2(aHWnd[n])
          nPos  := HB_UAt("(", cText)

          IF nPos > 0
            nPage := Val(Substr(cText, nPos + 1))
            EXIT
          ENDIF
        ENDIF
      NEXT

      IF nPage == 0
        FOR n := 1 TO Len(aHWnd)
          IF (GetClassName(aHWnd[n]) == "Edit") .and. (HB_BitAnd(GetWindowLongPtr(aHWnd[n], -16 /*GWL_STYLE*/), 0x2002 /*ES_NUMBER|ES_RIGHT*/) != 0)
            nPage := Val(GetWindowText2(aHWnd[n]))
            EXIT
          ENDIF
        NEXT
      ENDIF
    ENDIF
  ENDIF

RETURN nPage


/*
  Get page count in opened PDF
  Returns 0 if error loading occurs
*/
FUNCTION Sumatra_PageCount(cPanel)
  LOCAL nCount  := 0
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nHReBar
  LOCAL aHWnd
  LOCAL cText
  LOCAL nPos
  LOCAL n

  IF nHFrame != 0
    nHReBar := FindWindowEx(nHFrame, 0, "ReBarWindow32", 0)

    IF nHReBar != 0
      aHWnd := EnumChildWindows(nHReBar)

      FOR n := 1 TO Len(aHWnd)
        IF (GetClassName(aHWnd[n]) == "Static")
          cText := GetWindowText2(aHWnd[n])
          nPos  := HB_UAt("/", cText)

          IF nPos > 0
            nCount := Val(Substr(cText, nPos + 1))
            EXIT
          ENDIF
        ENDIF
      NEXT

    ENDIF
  ENDIF

RETURN nCount


/*
  nAction:
  -1 - find previous
   1 - find next
  otherwise - "Find" dialog
*/
FUNCTION Sumatra_FindText(cPanel, nAction)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nWParam

  IF nHFrame != 0
    HB_Default(@nAction, 0)

    SWITCH nAction
      CASE -1   ; nWParam := Sumatra_Command(cPanel, IDM_FIND_PREV)  ; EXIT
      CASE  1   ; nWParam := Sumatra_Command(cPanel, IDM_FIND_NEXT)  ; EXIT
      OTHERWISE ; nWParam := Sumatra_Command(cPanel, IDM_FIND_FIRST)
    ENDSWITCH

    PostMessage(nHFrame, 273 /*WM_COMMAND*/, nWParam, 0)
  ENDIF

RETURN NIL


FUNCTION Sumatra_SelectAll(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_SELECT_ALL), 0)
  ENDIF

RETURN NIL


FUNCTION Sumatra_GetSelText(cPanel)
  LOCAL cText   := ""
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL cClip

  IF nHFrame != 0
    cClip := GetClipboard()

    SetClipboard(cText)
    SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_COPY_SELECTION), 0)

    cText := GetClipboard()

    SetClipboard(cClip)
  ENDIF

RETURN cText


/*
  nAction:
  -1 - size down
   1 - size up
   2 - fit page
   3 - real size
   4 - fit width
  otherwise - "Zoom factor" dialog
*/
FUNCTION Sumatra_Zoom(cPanel, nAction)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    HB_Default(@nAction, 0)

    SWITCH nAction
      CASE -1
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDT_VIEW_ZOOMOUT), 0)
        EXIT
      CASE 1
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDT_VIEW_ZOOMIN), 0)
        EXIT
      CASE 2
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDT_VIEW_FIT_WIDTH), 0)
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_ZOOM_FIT_PAGE), 0)
        EXIT
      CASE 3
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDT_VIEW_FIT_WIDTH), 0)
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_ZOOM_ACTUAL_SIZE), 0)
        EXIT
      CASE 4
        SendMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDT_VIEW_FIT_WIDTH), 0)
        EXIT
      OTHERWISE
        PostMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_ZOOM_CUSTOM), 0)
    ENDSWITCH
  ENDIF

RETURN NIL


/*
  nAction:
  -1 - rotate left
   1 - rotate right
  otherwise - rotate 180°
*/
FUNCTION Sumatra_Rotate(cPanel, nAction)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nWParam

  IF nHFrame != 0
    HB_Default(@nAction, 0)

    IF nAction == -1
      nWParam := Sumatra_Command(cPanel, IDM_VIEW_ROTATE_LEFT)
    ELSE
      nWParam := Sumatra_Command(cPanel, IDM_VIEW_ROTATE_RIGHT)
    ENDIF

    SendMessage(nHFrame, 273 /*WM_COMMAND*/, nWParam, 0)

    IF nAction == 0
      SendMessage(nHFrame, 273 /*WM_COMMAND*/, nWParam, 0)
    ENDIF
  ENDIF

RETURN NIL


/*
  nAction:
   1 - single page (default)
   2 - facing (two pages)
   3 - book view
*/
FUNCTION Sumatra_View(cPanel, nAction)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nWParam

  IF nHFrame != 0
    HB_Default(@nAction, 1)

    SWITCH nAction
      CASE 1    ; nWParam := Sumatra_Command(cPanel, IDM_VIEW_SINGLE_PAGE) ; EXIT
      CASE 2    ; nWParam := Sumatra_Command(cPanel, IDM_VIEW_FACING)      ; EXIT
      OTHERWISE ; nWParam := Sumatra_Command(cPanel, IDM_VIEW_BOOK)
    ENDSWITCH

    SendMessage(nHFrame, 273 /*WM_COMMAND*/, nWParam, 0)
  ENDIF

RETURN NIL


FUNCTION Sumatra_About(cPanel)
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)

  IF nHFrame != 0
    PostMessage(nHFrame, 273 /*WM_COMMAND*/, Sumatra_Command(cPanel, IDM_ABOUT), 0)
  ENDIF

RETURN NIL


/*
  Sumatra_Version([cPanel], [cExeFile])
    - cPanel or cExeFile must be specified
    - if cPanel is specified, cExeFile is ignored
    return:
      - array of 4 integers: [major version, minor version, build, revision]
      - NIL if error occurs
*/
FUNCTION Sumatra_Version(cPanel, cExeFile)
  LOCAL nHFrame
  LOCAL nPID
  LOCAL aVersion

  IF HB_IsString(cPanel)
    nHFrame := Sumatra_FrameHandle(cPanel)

    IF nHFrame != 0
      GetWindowThreadProcessId(nHFrame, NIL, @nPID)

      cExeFile := GetProcessFullName(nPID)
    ENDIF
  ENDIF

  IF HB_IsString(cExeFile)
    aVersion := GetFileVersion(cExeFile)

    IF HB_IsArray(aVersion)
      RETURN aVersion
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Sumatra_Command(cPanel, nMsg)

  IF Sumatra_Version(cPanel)[2] == 2
    SWITCH nMsg
      CASE IDM_SAVEAS                 ; nMsg :=  406 ; EXIT
      CASE IDM_PRINT                  ; nMsg :=  408 ; EXIT
      CASE IDM_PROPERTIES             ; nMsg :=  420 ; EXIT
      CASE IDM_VIEW_SINGLE_PAGE       ; nMsg :=  422 ; EXIT
      CASE IDM_VIEW_FACING            ; nMsg :=  423 ; EXIT
      CASE IDM_VIEW_BOOK              ; nMsg :=  424 ; EXIT
      CASE IDM_VIEW_ROTATE_LEFT       ; nMsg :=  432 ; EXIT
      CASE IDM_VIEW_ROTATE_RIGHT      ; nMsg :=  434 ; EXIT
      CASE IDM_VIEW_BOOKMARKS         ; nMsg :=  436 ; EXIT
      CASE IDM_VIEW_SHOW_HIDE_TOOLBAR ; nMsg :=  440 ; EXIT
      CASE IDM_COPY_SELECTION         ; nMsg :=  442 ; EXIT
      CASE IDM_SELECT_ALL             ; nMsg :=  446 ; EXIT
      CASE IDM_GOTO_NEXT_PAGE         ; nMsg :=  460 ; EXIT
      CASE IDM_GOTO_PREV_PAGE         ; nMsg :=  462 ; EXIT
      CASE IDM_GOTO_FIRST_PAGE        ; nMsg :=  464 ; EXIT
      CASE IDM_GOTO_LAST_PAGE         ; nMsg :=  466 ; EXIT
      CASE IDM_GOTO_PAGE              ; nMsg :=  468 ; EXIT
      CASE IDM_FIND_FIRST             ; nMsg :=  470 ; EXIT
      CASE IDM_FIND_NEXT              ; nMsg :=  472 ; EXIT
      CASE IDM_FIND_PREV              ; nMsg :=  474 ; EXIT
      CASE IDM_ZOOM_FIT_PAGE          ; nMsg :=  480 ; EXIT
      CASE IDM_ZOOM_ACTUAL_SIZE       ; nMsg :=  481 ; EXIT
      CASE IDM_ZOOM_CUSTOM            ; nMsg :=  497 ; EXIT
      CASE IDM_ABOUT                  ; nMsg :=  584 ; EXIT
      CASE IDT_VIEW_ZOOMIN            ; nMsg := 3012 ; EXIT
      CASE IDT_VIEW_ZOOMOUT           ; nMsg := 3013 ; EXIT
      CASE IDT_VIEW_FIT_WIDTH         ; nMsg := 3026 ; EXIT
      CASE IDT_VIEW_FIT_PAGE          ; nMsg := 3027 ; EXIT
    ENDSWITCH
  ENDIF

RETURN nMsg


#pragma BEGINDUMP

#include "SET_COMPILE_HMG_UNICODE.ch"
#include "HMG_UNICODE.h"

#include <windows.h>
#include "hbapi.h"


       //GetFileVersion(cFileName)
HB_FUNC( GETFILEVERSION )
{
  LPCTSTR lpFileName = HMG_parc(1);
  DWORD   dwHandle;
  DWORD   dwSize;

  dwSize = GetFileVersionInfoSize(lpFileName, &dwHandle);

  if (dwSize == 0)
    return;

  CHAR lpData[dwSize];

  if (! GetFileVersionInfo(lpFileName, 0, dwSize, lpData))
    return;

  VS_FIXEDFILEINFO *lpFileInfo = NULL;
  UINT             uLen;

  if ((! VerQueryValue(lpData, _TEXT("\\"), (LPVOID*) &lpFileInfo, &uLen)) || (lpFileInfo == NULL) || (uLen == 0))
    return;

  hb_reta(4);
  hb_storvni((lpFileInfo->dwFileVersionMS >> 16) & 0xFFFF, -1, 1);
  hb_storvni(lpFileInfo->dwFileVersionMS & 0xFFFF,         -1, 2);
  hb_storvni((lpFileInfo->dwFileVersionLS >> 16) & 0xFFFF, -1, 3);
  hb_storvni(lpFileInfo->dwFileVersionLS & 0xFFFF,         -1, 4);
}


       //GetWindowText2(nHWnd) --> text from control created in another process
HB_FUNC( GETWINDOWTEXT2 )
{
  HWND   hWnd = (HWND)   HMG_parnl(1);
  INT    nLen = (INT)    SendMessage(hWnd, WM_GETTEXTLENGTH, 0, 0) + 1;
  LPTSTR Text = (LPTSTR) hb_xgrab(nLen * sizeof(TCHAR));

  SendMessage(hWnd, WM_GETTEXT, nLen, (LPARAM) Text);
  HMG_retc(Text);
  hb_xfree(Text);
}

#pragma ENDDUMP
