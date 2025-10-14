/*

  PDF viewer, merger and splitter using:
    SumatraPDF.exe ver. 3.1.2 or 3.2
    PDFtk.exe ver. 2.02

  Source files:
    PDFview.prg
    PDFview.rc
    PDFview_C.c
    PDFview_ErrorSys.prg
    PDFview_Keybd.ch
    PDFview_LangStr.ch
    Resource\BmpArrowS.bmp
    Resource\BmpArrowW.bmp
    Resource\BmpArrowE.bmp
    Resource\CurDragDrop.cur
    Resource\CurArrowNE.cur
    Resource\CurResizeWE.cur
    Resource\IcoPDF.ico

  Compiler: HMG 3.4.4

  Link with SumatraPDF library (libSumatraPDF.a) or include SumatraPDF.prg

*/

#define FCOLOR_DIRT      1
#define FCOLOR_DIRB      2
#define FCOLOR_DIRSELAT  3
#define FCOLOR_DIRSELAB  4
#define FCOLOR_DIRSELNT  5
#define FCOLOR_DIRSELNB  6
#define FCOLOR_PDFT      7
#define FCOLOR_PDFB      8
#define FCOLOR_PDFSELAT  9
#define FCOLOR_PDFSELAB 10
#define FCOLOR_PDFSELNT 11
#define FCOLOR_PDFSELNB 12

#define LABEL_NAME   1
#define LABEL_HWND   2
#define LABEL_EVENT  3
#define LABEL_FRAME  4
#define LABEL_COLOR  5
#define LABEL_VALUE  6

#define RECENTF_NAME 1
#define RECENTF_PAGE 2
#define RECENTF_PASS 3

#define MERGEF_NAME     1
#define MERGEF_PAGESIN  2
#define MERGEF_PAGESOUT 3
#define MERGEF_RANGEIN  4
#define MERGEF_RANGEOUT 5
#define MERGEF_RANGEERR 6
#define MERGEF_PASS     7

#xtranslate CRLF2 => HB_EOL() + HB_EOL()

#include "directry.ch"
#include "fileio.ch"
#include "hbver.ch"
#include "hmg.ch"
#include "PDFview_Keybd.ch"
#include "PDFview_LangStr.ch"
#include "SumatraPDF.ch"

MEMVAR _HMG_SYSDATA
MEMVAR _HMG_DEFAULTICONNAME

STATIC snHMenuMain
STATIC scProgName
STATIC saTab
STATIC saTabClosed
STATIC saPanel
STATIC slMenuActive
STATIC scDirStart

//saved in .ini
STATIC slPDFview_Max
STATIC snPDFview_R
STATIC snPDFview_C
STATIC snPDFview_W
STATIC snPDFview_H
STATIC snFiles_W
STATIC slPassShow
STATIC scFileDir
STATIC scFileLast
STATIC snRecent_W
STATIC snRecent_H
STATIC slRecentNames
STATIC snRecentAmount
STATIC snTranslate_W
STATIC snTranslate_H
STATIC scTranslateLang1
STATIC scTranslateLang2
STATIC snMerge_W
STATIC snMerge_H
STATIC slMergeNames
STATIC snZoom
STATIC slMenuBar
STATIC slStatusBar
STATIC slFilesPanel
STATIC slToolBar
STATIC slBookmarks
STATIC scLang
STATIC slSingleRunApp
STATIC slSingleOpenPDF
STATIC slOpenAtOnce
STATIC slSessionRest
STATIC slEscExit
STATIC slTabGoToFile
STATIC snTabNew
STATIC snTab_W
STATIC scSumatraDir
STATIC scPDFtkDir
STATIC saFColor

//saved in .recent
STATIC saSession
STATIC saRecent

DECLARE WINDOW MergeWnd
DECLARE WINDOW SplitWnd
DECLARE WINDOW BooksWnd


FUNCTION Main()
  LOCAL lOnGotFocus := .F.

  SET FONT TO "MS Shell Dlg", 8
  SET DEFAULT ICON TO "IcoPDF"

  SettingsRead()

  IF slSingleRunApp .and. IsProgramRunning()
    QUIT
  ENDIF

  DEFINE WINDOW PDFviewWnd;
    ROW    snPDFview_R;
    COL    snPDFview_C;
    WIDTH  snPDFview_W;
    HEIGHT snPDFview_H;
    MAIN;
    ON INIT     ((SessionOpen(1) .or. SessionOpen(3) .or. If(slFilesPanel .and. slOpenAtOnce .and. HB_FileExists(scFileDir + scFileLast), FileOpen(scFileDir + scFileLast), .F.)), ;
                 Files_Refresh(scFileLast));
    ON GOTFOCUS ((lOnGotFocus := .T.), Files_Refresh(PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME)), TabCloseAll(0), (lOnGotFocus := .F.));
    ON SIZE     PDFview_Resize(.T.);
    ON MAXIMIZE PDFview_Resize(.T.);
    ON RELEASE  (SettingsWrite(.T.), DestroyMenu(snHMenuMain))

    DEFINE GRID Files
      ROW              0
      COL              -1
      WIDTH            snFiles_W
      HEADERS          {NIL, NIL, NIL, NIL, NIL}
      WIDTHS           {snFiles_W - 4, 0, 0, 0, 0}
      CELLNAVIGATION   .T.
      DYNAMICFORECOLOR {{ || If("D" $ PDFviewWnd.Files.CellEx(This.CellRowIndex, F_ATTR), ColorArray(saFColor[FCOLOR_DIRT]), ColorArray(saFColor[FCOLOR_PDFT])) }, NIL, NIL, NIL, NIL}
      DYNAMICBACKCOLOR {{ || If("D" $ PDFviewWnd.Files.CellEx(This.CellRowIndex, F_ATTR), ColorArray(saFColor[FCOLOR_DIRB]), ColorArray(saFColor[FCOLOR_PDFB])) }, NIL, NIL, NIL, NIL}
      ONGOTFOCUS       Files_CellNavigationColor()
      ONLOSTFOCUS      Files_CellNavigationColor()
      ONCHANGE         (Files_CellNavigationColor(), ;
                        If(slFilesPanel .and. slOpenAtOnce .and. (! lOnGotFocus) .and. (! ("D" $ This.CellEx(This.VALUE[1], F_ATTR))), FileOpen(NIL, NIL, NIL, .T.), NIL))
      ONDBLCLICK       If(slFilesPanel, FileOpen(NIL, If(GetKeyState(VK_CONTROL) < 0, -1, 0), If(GetKeyState(VK_SHIFT) < 0, 0, -1)), NIL)
      ONKEY            Files_OnKey()
      ONHEADCLICK      {{ || Files_ChooseDir() }}
    END GRID

    DEFINE IMAGE FilesShow
      TRANSPARENT      .T.
      TRANSPARENTCOLOR WHITE
      PICTURE          If(slFilesPanel, "BmpArrowW", "BmpArrowE")
      ACTION           Files_Show()
    END IMAGE

    DEFINE TAB Tabs;
      ROW    0;
      COL    0;
      WIDTH  0;
      HEIGHT 20
    END TAB

    DEFINE STATUSBAR
      STATUSITEM ""
      STATUSITEM "" WIDTH 140
    END STATUSBAR
  END WINDOW

  SetClassLongPtr(PDFviewWnd.HANDLE, -26 /*GCL_STYLE*/, HB_BitOr(GetClassLongPtr(PDFviewWnd.HANDLE, -26 /*GCL_STYLE*/), 0x0008 /*CS_DBLCLKS*/))

  PDFviewWnd.STATUSBAR.VISIBLE := slStatusBar
  PDFviewWnd.Files.PAINTDOUBLEBUFFER := .T.

  IF slFilesPanel
    ListView_ChangeExtendedStyle(PDFviewWnd.Files.HANDLE, LVS_EX_INFOTIP)
  ENDIF

  HMG_ChangeWindowStyle(ListView_GetHeader(PDFviewWnd.Files.HANDLE), 0x0800 /*HDS_NOSIZING*/, NIL, .F., .F.)
  HMG_ChangeWindowStyle(PDFviewWnd.Tabs.HANDLE, 0x8000 /*TCS_FOCUSNEVER*/, NIL, .F., .F.)

  TabNew(1, PanelNew())

  IF slPDFview_Max
    PDFviewWnd.MAXIMIZE
  ENDIF

  PDFview_SetOnKey(.T.)
  SetLangInterface()
  PDFview_Resize(.T.)
  ChangeWindowMessageFilter(PDFviewWnd.HANDLE, 74 /*WM_COPYDATA*/, 1 /*MSGFLT_ALLOW*/)

  InstallEventHandler("MainEventHandler")
  EventProcessAllHookMessage(EventCreate("Tabs_EventHandler", PDFviewWnd.Tabs.HANDLE), .T.)

  DEFINE TIMER PdfTimer PARENT PDFviewWnd INTERVAL 100 ACTION Status_SetPage(.F.)

  PDFviewWnd.ACTIVATE

RETURN NIL


FUNCTION SetLangInterface(cNewLang)
  LOCAL cLabel
  LOCAL cNum
  LOCAL n

  IF ! (scLang == cNewLang)
    IF ! Empty(cNewLang)
      scLang := cNewLang

      IF slMenuBar
        ReleaseMainMenu("PDFviewWnd")
      ELSE
        DestroyMenu(snHMenuMain)
      ENDIF
    ENDIF

    DEFINE MAINMENU OF PDFviewWnd
      DEFINE POPUP LangStr(LS_File)
        MENUITEM LangStr(LS_OpenInNewTab) + e"...\tCtrl+O"             NAME FileOpenNewTab   ACTION FileGetAndOpen(.T.)
        MENUITEM LangStr(LS_OpenInCurTab) + e"...\tCtrl+Shift+O"       NAME FileOpenCurTab   ACTION FileGetAndOpen(.F.)
        SEPARATOR
        MENUITEM LangStr(LS_Print) + e"...\tCtrlt+Shift+P"             NAME FilePrint        ACTION FilePrintDirectly(.F.)
        SEPARATOR
        DEFINE POPUP LangStr(LS_OpenFromDir) NAME FileOpenInDir
          MENUITEM LangStr(LS_PrevPDF) + e"\tCtrl+Shift+<-"            NAME FileOpenPrev     ACTION FileOpenFromDir(-1)
          MENUITEM LangStr(LS_NextPDF) + e"\tCtrl+Shift+->"            NAME FileOpenNext     ACTION FileOpenFromDir( 1)
          MENUITEM LangStr(LS_FirstPDF) + e"\tCtrl+Shift+Home"         NAME FileOpenFirst    ACTION FileOpenFromDir(-2)
          MENUITEM LangStr(LS_LastPDF) + e"\tCtrl+Shift+-End"          NAME FileOpenLast     ACTION FileOpenFromDir( 2)
        END POPUP
        SEPARATOR
        MENUITEM LangStr(LS_OpenSession)                               NAME FileSession      ACTION SessionOpen(4)
        MENUITEM LangStr(LS_RecentFiles) + e"...\tCtrlt+Shift+R"       NAME FileRecent       ACTION RecentFiles()
        SEPARATOR
        MENUITEM LangStr(LS_Exit) + e"\tAlt+F4"                        NAME FileExit         ACTION ThisWindow.RELEASE
      END POPUP
      DEFINE POPUP LangStr(LS_Document)
        MENUITEM LangStr(LS_SaveAs) + e"...\tCtrl+S"                   NAME DocSaveAs        ACTION Sumatra_FileSaveAs(PanelName())
        MENUITEM LangStr(LS_Print) + e"...\tCtrl+P"                    NAME DocPrint         ACTION Sumatra_FilePrint(PanelName())
        MENUITEM LangStr(LS_Properties) + e"...\tCtrl+D"               NAME DocProper        ACTION Sumatra_FileProperties(PanelName())
        SEPARATOR
        MENUITEM LangStr(LS_SelectAllInDoc) + e"\tCtrl+A"              NAME DocSelectAll     ACTION Sumatra_SelectAll(PanelName())
        MENUITEM LangStr(LS_TranslateSel) + e"\tAlt+T"                 NAME DocTranslate     ACTION PdfTranslate()
        SEPARATOR
        DEFINE POPUP LangStr(LS_MoveTab) NAME DocMove
          MENUITEM LangStr(LS_Left) + e"\tShift+Alt+<-"                NAME DocMoveLeft      ACTION TabMove(-1)
          MENUITEM LangStr(LS_Right) + e"\tShift+Alt+->"               NAME DocMoveRight     ACTION TabMove(1)
          MENUITEM LangStr(LS_Beginning) + e"\tShift+Alt+Home"         NAME DocMoveBegin     ACTION TabMove(-2)
          MENUITEM LangStr(LS_End) + e"\tShift+Alt+End"                NAME DocMoveEnd       ACTION TabMove(2)
        END POPUP
        DEFINE POPUP LangStr(LS_Close) NAME DocClose
          MENUITEM LangStr(LS_CurrDoc) + e"\tCtrl+W"                   NAME DocCloseCurr     ACTION TabClose(0, .T.)
          MENUITEM LangStr(LS_DupDoc) + e"\tAlt+W"                     NAME DocCloseDup      ACTION TabCloseAll(3)
          MENUITEM LangStr(LS_AllDup) + e"\tShift+Alt+W"               NAME DocCloseAllDup   ACTION TabCloseAll(4)
          MENUITEM LangStr(LS_AllInactive) + e"\tCtrl+Alt+W"           NAME DocCloseInactive ACTION TabCloseAll(2)
          MENUITEM LangStr(LS_AllDoc) + e"\tCtrl+Shift+W"              NAME DocCloseAll      ACTION TabCloseAll(1)
        END POPUP
        MENUITEM LangStr(LS_RestoreLastTab) + e"\tCtrl+Shift+T"        NAME DocRestore       ACTION TabRestore()
        SEPARATOR
        MENUITEM LangStr(LS_ChooseDoc) + e"\tAlt+0"                    NAME DocChoose        ACTION Tabs_Menu(.F.)
        MENUITEM LangStr(LS_GoToFile) + e"\tCtrl+Shift+F"              NAME DocGoToFile      ACTION Files_GoTo(.T.)
        SEPARATOR
        DEFINE POPUP LangStr(LS_Tools)
          MENUITEM LangStr(LS_MergeSplitRotate) + e"...\tCtrl+Shift+M" NAME DocMerge         ACTION PdfMerge()
          MENUITEM LangStr(LS_SplitIntoPages) + e"...\tCtrl+Shift+S"   NAME DocSplit         ACTION PdfSplit()
          MENUITEM LangStr(LS_Bookmarks) + e"...\tCtrl+Shift+B"        NAME DocBooks         ACTION PdfBookmarks()
        END POPUP
      END POPUP
      DEFINE POPUP LangStr(LS_Page)
        MENUITEM LangStr(LS_GoTo) + e"...\tCtrl+G"                     NAME PageGoTo         ACTION Sumatra_PageGoTo(PanelName())
        SEPARATOR
        MENUITEM LangStr(LS_Prev) + e"\tCtrl+<-"                       NAME PagePrev         ACTION Sumatra_PageGoTo(PanelName(), -1)
        MENUITEM LangStr(LS_Next) + e"\tCtrl+->"                       NAME PageNext         ACTION Sumatra_PageGoTo(PanelName(),  1)
        MENUITEM LangStr(LS_First) + e"\tCtrl+Home"                    NAME PageFirst        ACTION Sumatra_PageGoTo(PanelName(), -2)
        MENUITEM LangStr(LS_Last) + e"\tCtrl+End"                      NAME PageLast         ACTION Sumatra_PageGoTo(PanelName(),  2)
      END POPUP
      DEFINE POPUP LangStr(LS_Find)
        MENUITEM LangStr(LS_Text) + e"...\tCtrl+F"                     NAME FindText         ACTION Sumatra_FindText(PanelName())
        SEPARATOR
        MENUITEM LangStr(LS_PrevOccur) + e"\tShift+F3"                 NAME FindPrev         ACTION Sumatra_FindText(PanelName(), -1)
        MENUITEM LangStr(LS_NextOccur) + e"\tF3"                       NAME FindNext         ACTION Sumatra_FindText(PanelName(),  1)
      END POPUP
      DEFINE POPUP LangStr(LS_Zoom)
        MENUITEM LangStr(LS_SizeDown) + e"\tCtrl+Minus"                NAME ZoomSizeDn       ACTION Sumatra_Zoom(PanelName(), -1)
        MENUITEM LangStr(LS_SizeUp) + e"\tCtrl+Plus"                   NAME ZoomSizeUp       ACTION Sumatra_Zoom(PanelName(),  1)
        MENUITEM LangStr(LS_ZoomFactor) + e"...\tCtrl+Y"               NAME ZoomFactor       ACTION Sumatra_Zoom(PanelName())
        SEPARATOR
        MENUITEM LangStr(LS_FitPage) + e"\tCtrl+0"                     NAME ZoomFitPage      ACTION SumatraSetZoom(2)
        MENUITEM LangStr(LS_ActualSize) + e"\tCtrl+1"                  NAME ZoomActual       ACTION SumatraSetZoom(3)
        MENUITEM LangStr(LS_FitWidth) + e"\tCtrl+2"                    NAME ZoomFitWidth     ACTION SumatraSetZoom(4)
      END POPUP
      DEFINE POPUP LangStr(LS_Rotate)
        MENUITEM LangStr(LS_Left)  + e" (-90°)\tCtrl+Shift+Minus"      NAME RotateLeft       ACTION Sumatra_Rotate(PanelName(), -1)
        MENUITEM LangStr(LS_Right) + e" (+90°)\tCtrl+Shift+Plus"       NAME RotateRight      ACTION Sumatra_Rotate(PanelName(),  1)
        MENUITEM LangStr(LS_Down)  + e" (180°)\tCtrl+Shift+Num*"       NAME RotateDown       ACTION Sumatra_Rotate(PanelName())
      END POPUP
      DEFINE POPUP LangStr(LS_View)
        MENUITEM LangStr(LS_MenuBar) + e"\tF9"                         NAME ViewMenuBar      ACTION SetMenu(PDFviewWnd.HANDLE, If((slMenuBar := ! slMenuBar), snHMenuMain, 0))
        MENUITEM LangStr(LS_StatusBar) + e"\tCtrl+F9"                  NAME ViewStatusBar    ACTION Status_Show()
        MENUITEM LangStr(LS_FilesPanel) + e"\tShift+F9"                NAME ViewFilesPanel   ACTION Files_Show()
        SEPARATOR
        MENUITEM LangStr(LS_ToolBar) + e"\tF8"                         NAME ViewToolBar      ACTION Sumatra_Toolbar(PanelName(), ! Sumatra_Toolbar(PanelName()))
        DEFINE POPUP LangStr(LS_Bookmarks) NAME ViewBookmarks
          MENUITEM LangStr(LS_Show) + e"\tF12"                         NAME ViewBookShow     ACTION Sumatra_Bookmarks(PanelName(), ! Sumatra_Bookmarks(PanelName()))
          SEPARATOR
          MENUITEM LangStr(LS_ExpandAll) + e"\tCtrl+F12"               NAME ViewBookExpand   ACTION Sumatra_BookmarksExpand(PanelName(), .T.)
          MENUITEM LangStr(LS_CollapseAll) + e"\tAlt+F12"              NAME ViewBookCollapse ACTION Sumatra_BookmarksExpand(PanelName(), .F.)
        END POPUP
      END POPUP
      DEFINE POPUP LangStr(LS_Settings)
        MENUITEM LangStr(LS_Options) + e"...\tCtrl+K"                  NAME PDFviewOptions   ACTION PDFviewOptions()
        SEPARATOR
        MENUITEM LangStr(LS_AboutPDFview) + e"...\tF1"                 NAME AboutPDFview     ACTION AboutPDFview()
        MENUITEM LangStr(LS_AboutSumatra) + e"...\tShift+F1"           NAME AboutSumatra     ACTION Sumatra_About(PanelName())
      END POPUP
    END MENU

    snHMenuMain := GetMenu(PDFviewWnd.HANDLE)

    IF ! slMenuBar
      SetMenu(PDFviewWnd.HANDLE, 0)
    ENDIF

    IF ! Empty(cNewLang)
      PDFviewWnd.REDRAW

      IF IsWindowActive(MergeWnd)
        MergeWnd.TITLE                := LangStr(LS_MergeSplitRotate, .T.)
        MergeWnd.Files.Header(1)      := LangStr(LS_Documents)
        MergeWnd.NamesCBox.CAPTION    := LangStr(LS_OnlyNames)
        MergeWnd.AddButton.CAPTION    := LangStr(LS_Add)
        MergeWnd.DupButton.CAPTION    := LangStr(LS_Duplicate)
        MergeWnd.RemoveButton.CAPTION := LangStr(LS_Remove)
        MergeWnd.UpButton.CAPTION     := LangStr(LS_Up)
        MergeWnd.DownButton.CAPTION   := LangStr(LS_Down)
        MergeWnd.RangesLabel.VALUE    := LangStr(LS_PageRanges) + ":"
        MergeWnd.PassFrame.CAPTION    := LangStr(LS_PassProtect)
        MergeWnd.OwnPassLabel.VALUE   := LangStr(LS_OwnerPass)
        MergeWnd.UserPassLabel.VALUE  := LangStr(LS_UserPass)
        MergeWnd.PassShowCBox.CAPTION := LangStr(LS_ShowPass)
        MergeWnd.MakeButton.CAPTION   := LangStr(LS_Make)
        MergeWnd.CloseButton.CAPTION  := LangStr(LS_Close)

        cLabel := MergeWnd.StatusLabel.VALUE
        
        IF ! Empty(cLabel)
          n    := HMG_Len(cLabel)
          cNum := ""

          DO WHILE IsDigit(HB_UTF8SubStr(cLabel, n, 1))
            cNum := HB_UTF8SubStr(cLabel, n, 1) + cNum
            --n
          ENDDO

          IF Empty(cNum)
            MergeWnd.StatusLabel.VALUE := LangStr(LS_Done)
          ELSE
            MergeWnd.StatusLabel.VALUE := LangStr(LS_TotalPages) + " " + cNum
          ENDIF
        ENDIF
      ENDIF

      IF IsWindowActive(SplitWnd)
        SplitWnd.TITLE                := LangStr(LS_SplitIntoPages, .T.)
        SplitWnd.DocLabel.VALUE       := LangStr(LS_Document, .T.) + ":"
        SplitWnd.RangesLabel.VALUE    := LangStr(LS_PageRanges) + ":"
        SplitWnd.OutDirLabel.VALUE    := LangStr(LS_OutputDir)
        SplitWnd.OutFilesLabel.VALUE  := LangStr(LS_TargetFiles)
        SplitWnd.PassFrame.CAPTION    := LangStr(LS_PassProtect)
        SplitWnd.OwnPassLabel.VALUE   := LangStr(LS_OwnerPass)
        SplitWnd.UserPassLabel.VALUE  := LangStr(LS_UserPass)
        SplitWnd.PassShowCBox.CAPTION := LangStr(LS_ShowPass)
        SplitWnd.MakeButton.CAPTION   := LangStr(LS_Make)
        SplitWnd.CloseButton.CAPTION  := LangStr(LS_Close)

        IF ! Empty(SplitWnd.StatusLabel.VALUE)
          SplitWnd.StatusLabel.VALUE := LangStr(LS_Done)
        ENDIF
      ENDIF

      IF IsWindowActive(BooksWnd)
        BooksWnd.TITLE                := LangStr(LS_Bookmarks, .T.)
        BooksWnd.DocLabel.VALUE       := LangStr(LS_Document, .T.) + ":"
        BooksWnd.RadioRG.Caption(1)   := LangStr(LS_SaveBooks)
        BooksWnd.RadioRG.Caption(2)   := LangStr(LS_RemoveBooks)
        BooksWnd.RadioRG.Caption(3)   := LangStr(LS_InsertBooks)
        BooksWnd.PassFrame.CAPTION    := LangStr(LS_PassProtect)
        BooksWnd.OwnPassLabel.VALUE   := LangStr(LS_OwnerPass)
        BooksWnd.UserPassLabel.VALUE  := LangStr(LS_UserPass)
        BooksWnd.PassShowCBox.CAPTION := LangStr(LS_ShowPass)
        BooksWnd.MakeButton.CAPTION   := LangStr(LS_Make)
        BooksWnd.CloseButton.CAPTION  := LangStr(LS_Close)
      ENDIF

      SessionReopen()
    ENDIF
  ENDIF

RETURN NIL


FUNCTION MenuCommandsEnable()
  LOCAL cPanel     := PanelName()
  LOCAL nPages     := Sumatra_PageCount(cPanel)
  LOCAL lPdfOpened := (Sumatra_FrameHandle(cPanel) != 0)
  LOCAL lPdfLoaded := (nPages > 0)
  LOCAL lMultiTab  := (Len(saTab) > 1)

  SumatraGetSettings()

  PDFviewWnd.FileOpenInDir.ENABLED    := lPdfOpened
  PDFviewWnd.FileSession.ENABLED      := ! Empty(saSession)
  PDFviewWnd.DocSaveAs.ENABLED        := lPdfLoaded
  PDFviewWnd.DocPrint.ENABLED         := lPdfLoaded
  PDFviewWnd.DocProper.ENABLED        := lPdfLoaded
  PDFviewWnd.DocMove.ENABLED          := lMultiTab
  PDFviewWnd.DocMoveLeft.ENABLED      := lMultiTab .and. (PDFviewWnd.Tabs.VALUE > 1)
  PDFviewWnd.DocMoveRight.ENABLED     := lMultiTab .and. (PDFviewWnd.Tabs.VALUE < Len(saTab))
  PDFviewWnd.DocMoveBegin.ENABLED     := lMultiTab .and. (PDFviewWnd.Tabs.VALUE > 1)
  PDFviewWnd.DocMoveEnd.ENABLED       := lMultiTab .and. (PDFviewWnd.Tabs.VALUE < Len(saTab))
  PDFviewWnd.DocClose.ENABLED         := lPdfOpened
  PDFviewWnd.DocCloseCurr.ENABLED     := lPdfOpened
  PDFviewWnd.DocCloseDup.ENABLED      := lMultiTab
  PDFviewWnd.DocCloseAllDup.ENABLED   := lMultiTab
  PDFviewWnd.DocCloseInactive.ENABLED := lMultiTab
  PDFviewWnd.DocCloseAll.ENABLED      := lMultiTab
  PDFviewWnd.DocRestore.ENABLED       := (! Empty(saTabClosed))
  PDFviewWnd.DocChoose.ENABLED        := lPdfOpened .or. (! Empty(saTabClosed))
  PDFviewWnd.DocGoToFile.ENABLED      := lPdfOpened
  PDFviewWnd.DocSelectAll.ENABLED     := lPdfLoaded
  PDFviewWnd.DocTranslate.ENABLED     := (! Empty(AllTrim(Sumatra_GetSelText(cPanel))))
  PDFviewWnd.PageGoto.ENABLED         := lPdfLoaded
  PDFviewWnd.PagePrev.ENABLED         := lPdfLoaded
  PDFviewWnd.PageNext.ENABLED         := lPdfLoaded
  PDFviewWnd.PageFirst.ENABLED        := lPdfLoaded
  PDFviewWnd.PageLast.ENABLED         := lPdfLoaded
  PDFviewWnd.FindText.ENABLED         := lPdfLoaded
  PDFviewWnd.FindPrev.ENABLED         := lPdfLoaded
  PDFviewWnd.FindNext.ENABLED         := lPdfLoaded
  PDFviewWnd.ZoomSizeDn.ENABLED       := lPdfLoaded
  PDFviewWnd.ZoomSizeUp.ENABLED       := lPdfLoaded
  PDFviewWnd.ZoomFactor.ENABLED       := lPdfLoaded
  PDFviewWnd.ZoomFitPage.ENABLED      := lPdfLoaded
  PDFviewWnd.ZoomActual.ENABLED       := lPdfLoaded
  PDFviewWnd.ZoomFitWidth.ENABLED     := lPdfLoaded
  PDFviewWnd.RotateDown.ENABLED       := lPdfLoaded
  PDFviewWnd.RotateLeft.ENABLED       := lPdfLoaded
  PDFviewWnd.RotateRight.ENABLED      := lPdfLoaded
  PDFviewWnd.ViewToolBar.ENABLED      := lPdfOpened
  PDFviewWnd.ViewBookmarks.ENABLED    := Sumatra_BookmarksExist(cPanel)
  PDFviewWnd.ViewBookExpand.ENABLED   := slBookmarks
  PDFviewWnd.ViewBookCollapse.ENABLED := slBookmarks
  PDFviewWnd.AboutSumatra.ENABLED     := lPdfOpened

  PDFviewWnd.ZoomFitPage.CHECKED    := (snZoom == 2)
  PDFviewWnd.ZoomActual.CHECKED     := (snZoom == 3)
  PDFviewWnd.ZoomFitWidth.CHECKED   := ((snZoom != 2) .and. (snZoom != 3))
  PDFviewWnd.ViewMenuBar.CHECKED    := slMenuBar
  PDFviewWnd.ViewStatusBar.CHECKED  := slStatusBar
  PDFviewWnd.ViewFilesPanel.CHECKED := slFilesPanel
  PDFviewWnd.ViewToolBar.CHECKED    := slToolBar
  PDFviewWnd.ViewBookmarks.CHECKED  := slBookmarks
  PDFviewWnd.ViewBookShow.CHECKED   := slBookmarks

RETURN NIL


FUNCTION ModelessSetFocus(cForm)

  SWITCH cForm
    CASE "PDFviewWnd"
      IF IsWindowActive(MergeWnd)
        IF MergeWnd.ISMINIMIZED
          MergeWnd.RESTORE
        ELSE
          MergeWnd.SETFOCUS
        ENDIF
      ELSEIF IsWindowActive(SplitWnd)
        IF SplitWnd.ISMINIMIZED
          SplitWnd.RESTORE
        ELSE
          SplitWnd.SETFOCUS
        ENDIF
      ELSEIF IsWindowActive(BooksWnd)
        IF BooksWnd.ISMINIMIZED
          BooksWnd.RESTORE
        ELSE
          BooksWnd.SETFOCUS
        ENDIF
      ENDIF
      EXIT
    CASE "MergeWnd"
      MergeWnd.MINIMIZE

      IF IsWindowActive(SplitWnd)
        SplitWnd.RESTORE
      ELSEIF IsWindowActive(BooksWnd)
        BooksWnd.RESTORE
      ENDIF
      EXIT
    CASE "SplitWnd"
      SplitWnd.MINIMIZE

      IF IsWindowActive(BooksWnd)
        BooksWnd.RESTORE
      ENDIF
      EXIT
    CASE "BooksWnd"
      BooksWnd.MINIMIZE
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION PDFview_SetOnKey(lSet)

  IF lSet
    ON KEY TAB                    OF PDFviewWnd ACTION PDFview_SetFocusNextCtl(.F.)
    ON KEY SHIFT+TAB              OF PDFviewWnd ACTION PDFview_SetFocusNextCtl(.T.)
    ON KEY CONTROL+TAB            OF PDFviewWnd ACTION TabChange(-1)
    ON KEY CONTROL+SHIFT+TAB      OF PDFviewWnd ACTION TabChange(-2)
    ON KEY CONTROL+O              OF PDFviewWnd ACTION FileGetAndOpen(.T.)
    ON KEY CONTROL+SHIFT+O        OF PDFviewWnd ACTION FileGetAndOpen(.F.)
    ON KEY CONTROL+SHIFT+LEFT     OF PDFviewWnd ACTION FileOpenFromDir(-1)
    ON KEY CONTROL+SHIFT+RIGHT    OF PDFviewWnd ACTION FileOpenFromDir( 1)
    ON KEY CONTROL+SHIFT+HOME     OF PDFviewWnd ACTION FileOpenFromDir(-2)
    ON KEY CONTROL+SHIFT+END      OF PDFviewWnd ACTION FileOpenFromDir( 2)
    ON KEY CONTROL+W              OF PDFviewWnd ACTION TabClose(0, .T.)
    ON KEY ALT+W                  OF PDFviewWnd ACTION TabCloseAll(3)
    ON KEY SHIFT+ALT+W            OF PDFviewWnd ACTION TabCloseAll(4)
    ON KEY CONTROL+ALT+W          OF PDFviewWnd ACTION TabCloseAll(2)
    ON KEY CONTROL+SHIFT+W        OF PDFviewWnd ACTION TabCloseAll(1)
    ON KEY CONTROL+S              OF PDFviewWnd ACTION Sumatra_FileSaveAs(PanelName())
    ON KEY CONTROL+P              OF PDFviewWnd ACTION Sumatra_FilePrint(PanelName())
    ON KEY CONTROL+D              OF PDFviewWnd ACTION Sumatra_FileProperties(PanelName())
    ON KEY CONTROL+A              OF PDFviewWnd ACTION Sumatra_SelectAll(PanelName())
    ON KEY CONTROL+SHIFT+B        OF PDFviewWnd ACTION PdfBookmarks()
    ON KEY CONTROL+SHIFT+F        OF PDFviewWnd ACTION Files_GoTo(.T.)
    ON KEY CONTROL+SHIFT+M        OF PDFviewWnd ACTION PdfMerge()
    ON KEY CONTROL+SHIFT+P        OF PDFviewWnd ACTION FilePrintDirectly(.F.)
    ON KEY CONTROL+SHIFT+R        OF PDFviewWnd ACTION RecentFiles()
    ON KEY CONTROL+SHIFT+S        OF PDFviewWnd ACTION PdfSplit()
    ON KEY CONTROL+SHIFT+T        OF PDFviewWnd ACTION TabRestore()
    ON KEY ALT+T                  OF PDFviewWnd ACTION PdfTranslate()
    ON KEY CONTROL+G              OF PDFviewWnd ACTION Sumatra_PageGoTo(PanelName())
    ON KEY CONTROL+LEFT           OF PDFviewWnd ACTION Sumatra_PageGoTo(PanelName(), -1)
    ON KEY CONTROL+RIGHT          OF PDFviewWnd ACTION Sumatra_PageGoTo(PanelName(),  1)
    ON KEY CONTROL+HOME           OF PDFviewWnd ACTION Sumatra_PageGoTo(PanelName(), -2)
    ON KEY CONTROL+END            OF PDFviewWnd ACTION Sumatra_PageGoTo(PanelName(),  2)
    ON KEY CONTROL+F              OF PDFviewWnd ACTION Sumatra_FindText(PanelName())
    ON KEY SHIFT+F3               OF PDFviewWnd ACTION Sumatra_FindText(PanelName(), -1)
    ON KEY F3                     OF PDFviewWnd ACTION Sumatra_FindText(PanelName(),  1)
    ON KEY CONTROL+MINUS          OF PDFviewWnd ACTION Sumatra_Zoom(PanelName(), -1)
    ON KEY CONTROL+SUBTRACT       OF PDFviewWnd ACTION Sumatra_Zoom(PanelName(), -1)
    ON KEY CONTROL+PLUS           OF PDFviewWnd ACTION Sumatra_Zoom(PanelName(),  1)
    ON KEY CONTROL+ADD            OF PDFviewWnd ACTION Sumatra_Zoom(PanelName(),  1)
    ON KEY CONTROL+Y              OF PDFviewWnd ACTION Sumatra_Zoom(PanelName())
    ON KEY CONTROL+0              OF PDFviewWnd ACTION SumatraSetZoom(2)
    ON KEY CONTROL+NUMPAD0        OF PDFviewWnd ACTION SumatraSetZoom(2)
    ON KEY CONTROL+1              OF PDFviewWnd ACTION SumatraSetZoom(3)
    ON KEY CONTROL+NUMPAD1        OF PDFviewWnd ACTION SumatraSetZoom(3)
    ON KEY CONTROL+2              OF PDFviewWnd ACTION SumatraSetZoom(4)
    ON KEY CONTROL+NUMPAD2        OF PDFviewWnd ACTION SumatraSetZoom(4)
    ON KEY CONTROL+6              OF PDFviewWnd ACTION Sumatra_View(PanelName(), 1)
    ON KEY CONTROL+NUMPAD6        OF PDFviewWnd ACTION Sumatra_View(PanelName(), 1)
    ON KEY CONTROL+7              OF PDFviewWnd ACTION Sumatra_View(PanelName(), 2)
    ON KEY CONTROL+NUMPAD7        OF PDFviewWnd ACTION Sumatra_View(PanelName(), 2)
    ON KEY CONTROL+8              OF PDFviewWnd ACTION Sumatra_View(PanelName(), 3)
    ON KEY CONTROL+NUMPAD8        OF PDFviewWnd ACTION Sumatra_View(PanelName(), 3)
    ON KEY CONTROL+SHIFT+MINUS    OF PDFviewWnd ACTION Sumatra_Rotate(PanelName(), -1)
    ON KEY CONTROL+SHIFT+SUBTRACT OF PDFviewWnd ACTION Sumatra_Rotate(PanelName(), -1)
    ON KEY CONTROL+SHIFT+PLUS     OF PDFviewWnd ACTION Sumatra_Rotate(PanelName(),  1)
    ON KEY CONTROL+SHIFT+ADD      OF PDFviewWnd ACTION Sumatra_Rotate(PanelName(),  1)
    ON KEY CONTROL+SHIFT+MULTIPLY OF PDFviewWnd ACTION Sumatra_Rotate(PanelName())
    ON KEY CONTROL+SHIFT+DIVIDE   OF PDFviewWnd ACTION Sumatra_Rotate(PanelName())
    ON KEY F9                     OF PDFviewWnd ACTION SetMenu(PDFviewWnd.HANDLE, If((slMenuBar := ! slMenuBar), snHMenuMain, 0))
    ON KEY CONTROL+F9             OF PDFviewWnd ACTION Status_Show()
    ON KEY SHIFT+F9               OF PDFviewWnd ACTION Files_Show()
    ON KEY F8                     OF PDFviewWnd ACTION Sumatra_Toolbar(PanelName(), ! Sumatra_Toolbar(PanelName()))
    ON KEY CONTROL+F12            OF PDFviewWnd ACTION Sumatra_BookmarksExpand(PanelName(), .T.)
    ON KEY ALT+F12                OF PDFviewWnd ACTION Sumatra_BookmarksExpand(PanelName(), .F.)
    ON KEY ALT+RETURN             OF PDFviewWnd ACTION If(IsMaximized(PDFviewWnd.HANDLE), PDFviewWnd.RESTORE, PDFviewWnd.MAXIMIZE)
    ON KEY SHIFT+ALT+RETURN       OF PDFviewWnd ACTION PDFviewWnd.MINIMIZE
    ON KEY ALT+1                  OF PDFviewWnd ACTION TabChange(1)
    ON KEY ALT+2                  OF PDFviewWnd ACTION TabChange(2)
    ON KEY ALT+3                  OF PDFviewWnd ACTION TabChange(3)
    ON KEY ALT+4                  OF PDFviewWnd ACTION TabChange(4)
    ON KEY ALT+5                  OF PDFviewWnd ACTION TabChange(5)
    ON KEY ALT+6                  OF PDFviewWnd ACTION TabChange(6)
    ON KEY ALT+7                  OF PDFviewWnd ACTION TabChange(7)
    ON KEY ALT+8                  OF PDFviewWnd ACTION TabChange(8)
    ON KEY ALT+9                  OF PDFviewWnd ACTION TabChange(9)
    ON KEY ALT+0                  OF PDFviewWnd ACTION Tabs_Menu(.F.)
    ON KEY ALT+HOME               OF PDFviewWnd ACTION TabChange(1)
    ON KEY ALT+END                OF PDFviewWnd ACTION TabChange(0)
    ON KEY ALT+NUMPAD1            OF PDFviewWnd ACTION TabChange(1)
    ON KEY ALT+NUMPAD2            OF PDFviewWnd ACTION TabChange(2)
    ON KEY ALT+NUMPAD3            OF PDFviewWnd ACTION TabChange(3)
    ON KEY ALT+NUMPAD4            OF PDFviewWnd ACTION TabChange(4)
    ON KEY ALT+NUMPAD5            OF PDFviewWnd ACTION TabChange(5)
    ON KEY ALT+NUMPAD6            OF PDFviewWnd ACTION TabChange(6)
    ON KEY ALT+NUMPAD7            OF PDFviewWnd ACTION TabChange(7)
    ON KEY ALT+NUMPAD8            OF PDFviewWnd ACTION TabChange(8)
    ON KEY ALT+NUMPAD9            OF PDFviewWnd ACTION TabChange(9)
    ON KEY ALT+NUMPAD0            OF PDFviewWnd ACTION Tabs_Menu(.F.)
    ON KEY SHIFT+ALT+LEFT         OF PDFviewWnd ACTION TabMove(-1)
    ON KEY SHIFT+ALT+RIGHT        OF PDFviewWnd ACTION TabMove(1)
    ON KEY SHIFT+ALT+HOME         OF PDFviewWnd ACTION TabMove(-2)
    ON KEY SHIFT+ALT+END          OF PDFviewWnd ACTION TabMove(2)
    ON KEY CONTROL+K              OF PDFviewWnd ACTION PDFviewOptions()
    ON KEY F1                     OF PDFviewWnd ACTION AboutPDFview()
    ON KEY SHIFT+F1               OF PDFviewWnd ACTION Sumatra_About(PanelName())
    ON KEY F6                     OF PDFviewWnd ACTION ModelessSetFocus(ThisWindow.NAME)

    IF slEscExit
      ON KEY ESCAPE OF PDFviewWnd ACTION PDFviewWnd.RELEASE
    ELSE
      RELEASE KEY ESCAPE OF PDFviewWnd
    ENDIF
  ELSE
    RELEASE KEY TAB                    OF PDFviewWnd
    RELEASE KEY SHIFT+TAB              OF PDFviewWnd
    RELEASE KEY CONTROL+TAB            OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+TAB      OF PDFviewWnd
    RELEASE KEY CONTROL+O              OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+O        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+LEFT     OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+RIGHT    OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+HOME     OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+END      OF PDFviewWnd
    RELEASE KEY CONTROL+W              OF PDFviewWnd
    RELEASE KEY ALT+W                  OF PDFviewWnd
    RELEASE KEY CONTROL+ALT+W          OF PDFviewWnd
    RELEASE KEY SHIFT+ALT+W            OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+W        OF PDFviewWnd
    RELEASE KEY CONTROL+S              OF PDFviewWnd
    RELEASE KEY CONTROL+P              OF PDFviewWnd
    RELEASE KEY CONTROL+D              OF PDFviewWnd
    RELEASE KEY CONTROL+A              OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+B        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+F        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+M        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+P        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+R        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+S        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+T        OF PDFviewWnd
    RELEASE KEY ALT+T                  OF PDFviewWnd
    RELEASE KEY CONTROL+G              OF PDFviewWnd
    RELEASE KEY CONTROL+LEFT           OF PDFviewWnd
    RELEASE KEY CONTROL+RIGHT          OF PDFviewWnd
    RELEASE KEY CONTROL+HOME           OF PDFviewWnd
    RELEASE KEY CONTROL+END            OF PDFviewWnd
    RELEASE KEY CONTROL+F              OF PDFviewWnd
    RELEASE KEY SHIFT+F3               OF PDFviewWnd
    RELEASE KEY F3                     OF PDFviewWnd
    RELEASE KEY CONTROL+MINUS          OF PDFviewWnd
    RELEASE KEY CONTROL+SUBTRACT       OF PDFviewWnd
    RELEASE KEY CONTROL+PLUS           OF PDFviewWnd
    RELEASE KEY CONTROL+ADD            OF PDFviewWnd
    RELEASE KEY CONTROL+Y              OF PDFviewWnd
    RELEASE KEY CONTROL+0              OF PDFviewWnd
    RELEASE KEY CONTROL+NUMPAD0        OF PDFviewWnd
    RELEASE KEY CONTROL+1              OF PDFviewWnd
    RELEASE KEY CONTROL+NUMPAD1        OF PDFviewWnd
    RELEASE KEY CONTROL+2              OF PDFviewWnd
    RELEASE KEY CONTROL+NUMPAD2        OF PDFviewWnd
    RELEASE KEY CONTROL+6              OF PDFviewWnd
    RELEASE KEY CONTROL+NUMPAD6        OF PDFviewWnd
    RELEASE KEY CONTROL+7              OF PDFviewWnd
    RELEASE KEY CONTROL+NUMPAD7        OF PDFviewWnd
    RELEASE KEY CONTROL+8              OF PDFviewWnd
    RELEASE KEY CONTROL+NUMPAD8        OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+MINUS    OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+SUBTRACT OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+PLUS     OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+ADD      OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+MULTIPLY OF PDFviewWnd
    RELEASE KEY CONTROL+SHIFT+DIVIDE   OF PDFviewWnd
    RELEASE KEY F9                     OF PDFviewWnd
    RELEASE KEY CONTROL+F9             OF PDFviewWnd
    RELEASE KEY SHIFT+F9               OF PDFviewWnd
    RELEASE KEY F8                     OF PDFviewWnd
    RELEASE KEY CONTROL+F12            OF PDFviewWnd
    RELEASE KEY ALT+F12                OF PDFviewWnd
    RELEASE KEY ALT+RETURN             OF PDFviewWnd
    RELEASE KEY SHIFT+ALT+RETURN       OF PDFviewWnd
    RELEASE KEY ALT+1                  OF PDFviewWnd
    RELEASE KEY ALT+2                  OF PDFviewWnd
    RELEASE KEY ALT+3                  OF PDFviewWnd
    RELEASE KEY ALT+4                  OF PDFviewWnd
    RELEASE KEY ALT+5                  OF PDFviewWnd
    RELEASE KEY ALT+6                  OF PDFviewWnd
    RELEASE KEY ALT+7                  OF PDFviewWnd
    RELEASE KEY ALT+8                  OF PDFviewWnd
    RELEASE KEY ALT+9                  OF PDFviewWnd
    RELEASE KEY ALT+0                  OF PDFviewWnd
    RELEASE KEY ALT+HOME               OF PDFviewWnd
    RELEASE KEY ALT+END                OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD1            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD2            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD3            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD4            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD5            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD6            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD7            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD8            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD9            OF PDFviewWnd
    RELEASE KEY ALT+NUMPAD0            OF PDFviewWnd
    RELEASE KEY SHIFT+ALT+LEFT         OF PDFviewWnd
    RELEASE KEY SHIFT+ALT+RIGHT        OF PDFviewWnd
    RELEASE KEY SHIFT+ALT+HOME         OF PDFviewWnd
    RELEASE KEY SHIFT+ALT+END          OF PDFviewWnd
    RELEASE KEY CONTROL+K              OF PDFviewWnd
    RELEASE KEY F1                     OF PDFviewWnd
    RELEASE KEY SHIFT+F1               OF PDFviewWnd
    RELEASE KEY F6                     OF PDFviewWnd
    RELEASE KEY ESCAPE                 OF PDFviewWnd
  ENDIF

RETURN NIL


FUNCTION PDFview_SetFocusNextCtl(lPrevious)
  LOCAL nHFocus := GetFocus()
  LOCAL cPanel  := PanelName()
  LOCAL nHFrame := Sumatra_FrameHandle(cPanel)
  LOCAL nHBook

  IF nHFrame != 0
    nHBook := Sumatra_BookmarksHandle(cPanel)

    IF nHFocus == PDFviewWnd.Files.HANDLE
      SetFocus(If(lPrevious, nHFrame, If(Sumatra_Bookmarks(cPanel), nHBook, nHFrame)))
    ELSEIF nHFocus == nHBook
      IF slFilesPanel
        SetFocus(If(lPrevious, PDFviewWnd.Files.HANDLE, nHFrame))
      ELSE
        SetFocus(nHFrame)
      ENDIF
    ELSE
      IF slFilesPanel
        SetFocus(If(lPrevious, If(Sumatra_Bookmarks(cPanel), nHBook, PDFviewWnd.Files.HANDLE), PDFviewWnd.Files.HANDLE))
      ELSEIF Sumatra_Bookmarks(cPanel)
        SetFocus(nHBook)
      ENDIF
    ENDIF
  ENDIF

RETURN NIL


FUNCTION PDFview_Resize(lAll)
  LOCAL cPanel  := PanelName()
  LOCAL nMainCW := PDFviewWnd.CLIENTAREAWIDTH
  LOCAL nMainCH := PDFviewWnd.CLIENTAREAHEIGHT - If(slStatusBar, GetWindowHeight(PDFviewWnd.STATUSBAR.HANDLE), 0)
  LOCAL nFilesC := PDFviewWnd.Files.COL
  LOCAL nFilesW := If(slFilesPanel, snFiles_W, 1)
  LOCAL nTabsH  := If(PDFviewWnd.Tabs.VISIBLE, PDFviewWnd.Tabs.HEIGHT, 0)
  LOCAL nImageW := PDFviewWnd.FilesShow.WIDTH

  IF lAll
    IF slFilesPanel .and. ((nMainCW - (nFilesC + nFilesW + nImageW)) < 200)
      nFilesW   := nMainCW - nFilesC - nImageW - 200
      snFiles_W := nFilesW
    ENDIF

    PDFviewWnd.Files.WIDTH  := nFilesW
    PDFviewWnd.Files.HEIGHT := nMainCH
    PDFviewWnd.Files.ColumnWIDTH(1) := nFilesW - 4 - If(PDFviewWnd.Files.ITEMCOUNT > ListViewGetCountPerPage(PDFviewWnd.Files.HANDLE), GetVScrollBarWidth(), 0)

    PDFviewWnd.FilesShow.ROW := Int(nMainCH / 2)
    PDFviewWnd.FilesShow.COL := nFilesC + nFilesW

    PDFviewWnd.Tabs.COL   := nFilesC + nFilesW + nImageW
    PDFviewWnd.Tabs.WIDTH := nMainCW - (nFilesC + nFilesW + nImageW)

    SendMessage(PDFviewWnd.Files.HANDLE, 0x1013 /*LVM_ENSUREVISIBLE*/, PDFviewWnd.Files.VALUE[1] - 1, 0)
  ENDIF

  //bug in MHG: SetProperty(cPanel, "ROW", nRow), SetProperty(cPanel, "COL", nCol)
  //reported: http://www.hmgforum.com/viewtopic.php?f=20&t=5178
  SetProperty(cPanel, "ROW", ClientToScreenRow(PDFviewWnd.HANDLE, nTabsH))
  SetProperty(cPanel, "COL", ClientToScreenCol(PDFviewWnd.HANDLE, nFilesC + nFilesW + nImageW))
  SetProperty(cPanel, "WIDTH", nMainCW - (nFilesC + nFilesW + nImageW))
  SetProperty(cPanel, "HEIGHT", nMainCH - nTabsH)

  Sumatra_FrameAdjust(cPanel)

RETURN NIL


FUNCTION Files_Show()
  LOCAL nHFrame

  slFilesPanel := ! slFilesPanel

  IF slFilesPanel
    PDFviewWnd.FilesShow.PICTURE := "BmpArrowW"
    ListView_ChangeExtendedStyle(PDFviewWnd.Files.HANDLE, LVS_EX_INFOTIP)
  ELSE
    PDFviewWnd.FilesShow.PICTURE := "BmpArrowE"
    ListView_ChangeExtendedStyle(PDFviewWnd.Files.HANDLE, NIL, LVS_EX_INFOTIP)

    IF GetFocus() == PDFviewWnd.Files.HANDLE
      nHFrame := Sumatra_FrameHandle(PanelName())

      IF nHFrame != 0
        SetFocus(nHFrame)
      ENDIF
    ENDIF
  ENDIF

  PDFview_Resize(.T.)

RETURN NIL


FUNCTION Files_OnKey()

  IF ! slMenuActive
    SWITCH HMG_GetLastVirtualKeyDown()
      CASE VK_F2
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) >= 0)
            Files_RenameDlg()
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_F5
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) >= 0)
            Files_Refresh(PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME))
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_F8
      CASE VK_DELETE
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

        IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) < 0) .and. (GetKeyState(VK_MENU) >= 0)
            Files_Delete()
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_F12
        HMG_CleanLastVirtualKeyDown()

        IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) >= 0)
          Sumatra_Bookmarks(PanelName(), ! Sumatra_Bookmarks(PanelName()))
          PDFviewWnd.Files.SETFOCUS
        ENDIF
        RETURN 1

      CASE VK_LEFT
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) >= 0) .and. (PDFviewWnd.Files.CellEx(1, F_NAME) == "..")
            PDFviewWnd.Files.VALUE := {1, 1}
            Files_CellNavigationColor()
            FileOpen()
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_RIGHT
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) >= 0) .and. ;
             ("D" $ PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_ATTR)) .and. ;
             (! (PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME) == ".."))
            FileOpen()
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_D
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) < 0) .and. (GetKeyState(VK_SHIFT) < 0) .and. (GetKeyState(VK_MENU) >= 0)
            Files_ChooseDir()
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_E
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) < 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) >= 0)
            Files_Properties()
          ENDIF
        ENDIF
        RETURN 1

      CASE VK_P
        IF slFilesPanel
          HMG_CleanLastVirtualKeyDown()

          IF (GetKeyState(VK_CONTROL) < 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) < 0)
            FilePrintDirectly(.T.)
          ENDIF
        ENDIF
        RETURN 1
    ENDSWITCH
  ENDIF

RETURN NIL


FUNCTION Files_Refresh(cFileSel)
  LOCAL nPosSel
  LOCAL aDirectory
  LOCAL nLen
  LOCAL n

  nPosSel := PDFviewWnd.Files.VALUE[1]

  EnableWindowRedraw(PDFviewWnd.Files.HANDLE, .F.)
  PDFviewWnd.Files.DELETEALLITEMS

  IF ! Empty(scFileDir)
    IF VolSerial(HB_UTF8Left(scFileDir, 3)) == -1
      cFileSel  := HB_UTF8Left(scFileDir, 2)
      scFileDir := ""
    ELSE
      DO WHILE ! HB_DirExists(scFileDir)
        cFileSel  := ""
        scFileDir := DirParent(scFileDir)
      ENDDO
    ENDIF
  ENDIF

  IF Empty(scFileDir)
    FOR n := 65 TO 90 //from "A" to "Z"
      IF IsDisk(Chr(n))
        PDFviewWnd.Files.AddItem({Chr(n) + ":", 0, "", "", "DK"})

        IF HMG_StrCmp(Chr(n) + ":", cFileSel, .F.) == 0
          nPosSel := PDFviewWnd.Files.ITEMCOUNT
        ENDIF
      ENDIF
    NEXT
  ELSE
    aDirectory := Directory(scFileDir + "*.*", "DHS")

    FOR n := Len(aDirectory) TO 1 STEP -1
      IF "D" $ aDirectory[n][F_ATTR]
        IF (aDirectory[n][F_NAME] == ".") .or. (aDirectory[n][F_NAME] == "..")
          HB_aDel(aDirectory, n, .T.)
        ENDIF
      ELSEIF HMG_StrCmp(HB_FNameExt(aDirectory[n][F_NAME]), ".pdf", .F.) != 0
        HB_aDel(aDirectory, n, .T.)
      ENDIF
    NEXT

    aSort(aDirectory, NIL, NIL, ;
          {|a1, a2|
            IF ("D" $ a1[F_ATTR]) .and. (! ("D" $ a2[F_ATTR]))
              RETURN .T.
            ELSEIF (! ("D" $ a1[F_ATTR])) .and. ("D" $ a2[F_ATTR])
              RETURN .F.
            ENDIF
            RETURN (HMG_StrCmp(HB_fNameName(a1[F_NAME]), HB_fNameName(a2[F_NAME]), .F.) < 0)
          })

    HB_aIns(aDirectory, 1, {"..", 0, "", "", "D"}, .T.)

    nLen := Len(aDirectory)

    FOR n := 1 TO nLen
      PDFviewWnd.Files.AddItem(aDirectory[n])

      IF aDirectory[n][F_NAME] == cFileSel
        nPosSel := n
      ENDIF
    NEXT
  ENDIF

  EnableWindowRedraw(PDFviewWnd.Files.HANDLE, .T., .T.)

  PDFviewWnd.Files.VALUE := {nPosSel, 1}
  Files_CellNavigationColor()

  PDFviewWnd.Files.ColumnWIDTH(1) := PDFviewWnd.Files.WIDTH - 4 - If(PDFviewWnd.Files.ITEMCOUNT > ListViewGetCountPerPage(PDFviewWnd.Files.HANDLE), GetVScrollBarWidth(), 0)
  PDFviewWnd.Files.Header(1) := If(Empty(scFileDir), LangStr(LS_Drive), scFileDir)

RETURN NIL


FUNCTION Files_GoTo(lShowFilesPanel)
  LOCAL cFile
  LOCAL cDir
  LOCAL nCount
  LOCAL lOpenAtOnce
  LOCAL n

  IF ! saPanel[saTab[PDFviewWnd.Tabs.VALUE]]
    cFile := Sumatra_FileName(PanelName())

    IF HB_FileExists(cFile)
      IF HB_IsLogical(lShowFilesPanel) .and. lShowFilesPanel .and. (! slFilesPanel)
        Files_Show()
      ENDIF

      cDir  := HB_fNameDir(cFile)
      cFile := HB_fNameNameExt(cFile)

      lOpenAtOnce  := slOpenAtOnce
      slOpenAtOnce := .F.

      IF HMG_StrCmp(cDir, scFileDir, .F.) == 0
        nCount := PDFviewWnd.Files.ITEMCOUNT

        FOR n := 1 TO nCount
          IF HMG_StrCmp(cFile, PDFviewWnd.Files.CellEx(n, F_NAME), .F.) == 0
            PDFviewWnd.Files.VALUE := {n, 1}
            Files_CellNavigationColor()
            EXIT
          ENDIF
        NEXT
      ELSE
        scFileDir := cDir
        Files_Refresh(cFile)
      ENDIF

      scFileLast   := cFile
      slOpenAtOnce := lOpenAtOnce
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Files_ChooseDir()
  LOCAL nRow
  LOCAL nCol
  LOCAL cDir

  nRow := GetProperty(PanelName(), "ROW")
  nCol := GetProperty(PanelName(), "COL")

  ClientToScreen(PDFviewWnd.HANDLE, @nCol, @nRow)

  cDir := BrowseForFolder(CRLF + LangStr(LS_ChooseDir, .T.) + ":", HB_BitOr(BIF_NEWDIALOGSTYLE, BIF_NONEWFOLDERBUTTON), NIL, NIL, scFileDir, nRow, nCol)

  IF ! Empty(cDir)
    cDir := DirSepAdd(cDir)

    IF HMG_StrCmp(cDir, scFileDir, .F.) != 0
      scFileDir := cDir
      Files_Refresh("..")
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Files_CellNavigationColor()
  LOCAL aBColor, aTColor

  IF "D" $ PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_ATTR)
    IF PDFviewWnd.Files.HANDLE == GetFocus()
      aTColor := ColorArray(saFColor[FCOLOR_DIRSELAT])
      aBColor := ColorArray(saFColor[FCOLOR_DIRSELAB])
    ELSE
      aTColor := ColorArray(saFColor[FCOLOR_DIRSELNT])
      aBColor := ColorArray(saFColor[FCOLOR_DIRSELNB])
    ENDIF
  ELSE
    IF PDFviewWnd.Files.HANDLE == GetFocus()
      aTColor := ColorArray(saFColor[FCOLOR_PDFSELAT])
      aBColor := ColorArray(saFColor[FCOLOR_PDFSELAB])
    ELSE
      aTColor := ColorArray(saFColor[FCOLOR_PDFSELNT])
      aBColor := ColorArray(saFColor[FCOLOR_PDFSELNB])
    ENDIF
  ENDIF

  CellNavigationColor(_SELECTEDCELL_FORECOLOR, aTColor)
  CellNavigationColor(_SELECTEDROW_FORECOLOR,  aTColor)
  CellNavigationColor(_SELECTEDCELL_BACKCOLOR, aBColor)
  CellNavigationColor(_SELECTEDROW_BACKCOLOR,  aBColor)

  ListView_RedrawItems(PDFviewWnd.Files.HANDLE, PDFviewWnd.Files.VALUE[1] - 1, PDFviewWnd.Files.VALUE[1] - 1)

RETURN NIL


FUNCTION Files_GetDefaultColors()

RETURN {0x000000, 0x9FFFFF, 0xFFFFFF, 0x003F7F, 0x000000, 0x00DFFF, 0x000000, 0x9FFF9F, 0xFFFFFF, 0x007F00, 0x000000, 0x00FF00}


FUNCTION Files_Menu(nRow, nCol)
  LOCAL nPos := PDFviewWnd.Files.VALUE[1]
  LOCAL aRect
  LOCAL lDrive
  LOCAL lDir
  LOCAL lParent
  LOCAL nHMenu
  LOCAL nCmd

  //menu from keyboard
  IF nRow == 0xFFFF
    SendMessage(PDFviewWnd.Files.HANDLE, 0x1013 /*LVM_ENSUREVISIBLE*/, nPos - 1, 0)
  ENDIF

  aRect    := ListView_GetItemRect(PDFviewWnd.Files.HANDLE, nPos - 1)
  aRect[4] := ClientToScreenRow(PDFviewWnd.Files.HANDLE, aRect[1] + aRect[4])
  aRect[1] := ClientToScreenRow(PDFviewWnd.Files.HANDLE, aRect[1])
  aRect[2] := ClientToScreenCol(PDFviewWnd.Files.HANDLE, aRect[2])

  IF nRow == 0xFFFF
    nRow := aRect[4]
    nCol := aRect[2]
  ELSEIF (nRow < aRect[1]) .or. (nRow > aRect[4])
    RETURN NIL
  ENDIF

  lDrive  := ("K" $ PDFviewWnd.Files.CellEx(nPos, F_ATTR))
  lDir    := ("D" $ PDFviewWnd.Files.CellEx(nPos, F_ATTR))
  lParent := (PDFviewWnd.Files.CellEx(nPos, F_NAME) == "..")
  nHMenu  := CreatePopupMenu()

  IF ! lDir
    AppendMenuString(nHMenu, 1, LangStr(LS_OpenInNewTab) + e"\tEnter")
    AppendMenuString(nHMenu, 2, LangStr(LS_OpenInCurTab) + e"\tShift+Enter")
    AppendMenuSeparator(nHMenu)
    AppendMenuString(nHMenu, 3, LangStr(LS_OpenPageInNewTab) + e"...\tCtrlt+Enter")
    AppendMenuString(nHMenu, 4, LangStr(LS_OpenPageInCurTab) + e"...\tCtrlt+Shift+Enter")
    AppendMenuSeparator(nHMenu)
    AppendMenuString(nHMenu, 5, LangStr(LS_Print) + e"...\tCtrlt+Alt+P")
    AppendMenuSeparator(nHMenu)
  ENDIF

  IF (! lDrive) .and. (! lParent)
    AppendMenuString(nHMenu, 6, LangStr(LS_Rename) + e"...\tF2")
    AppendMenuString(nHMenu, 7, LangStr(LS_Delete) + e"...\tShift+Del (Shift+F8)")
  ENDIF

  AppendMenuString(nHMenu, 8, LangStr(LS_Properties) + e"...\tCtrlt+E")
  AppendMenuSeparator(nHMenu)

  IF ! lDrive
    AppendMenuString(nHMenu, 9, LangStr(LS_GoToParentDir) + e"\t<-")
  ENDIF

  IF lDir .and. (! lParent)
    AppendMenuString(nHMenu, 10, LangStr(LS_GoToSubDir) + e"\t-> (Enter)")
  ENDIF

  AppendMenuString(nHMenu, 11, LangStr(LS_ChooseDir) + e"...\tCtrlt+Shift+D")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 12, LangStr(LS_RefreshList) + e"\tF5")

  slMenuActive := .T.
  PDFview_SetOnKey(.F.)

  nCmd := TrackPopupMenu2(nHMenu, 0x0180 /*TPM_NONOTIFY|TPM_RETURNCMD*/, nRow, nCol, PDFviewWnd.HANDLE)

  DestroyMenu(nHMenu)
  PDFview_SetOnKey(.T.)
  slMenuActive := .F.

  SWITCH nCmd
    CASE 9
      PDFviewWnd.Files.VALUE := {1, 1}
      Files_CellNavigationColor()
    CASE 2
    CASE 10
      FileOpen()
      EXIT
    CASE 1
      FileOpen(NIL, 0, -1)
      EXIT
    CASE 3
      FileOpen(NIL, -1, -1)
      EXIT
    CASE 4
      FileOpen(NIL, -1, 0)
      EXIT
    CASE 5
      FilePrintDirectly(.T.)
      EXIT
    CASE 6
      Files_RenameDlg()
      EXIT
    CASE 7
      Files_Delete()
      EXIT
    CASE 8
      Files_Properties()
      EXIT
    CASE 11
      Files_ChooseDir()
      EXIT
    CASE 12
      Files_Refresh(PDFviewWnd.Files.CellEx(nPos, F_NAME))
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION Files_RenameDlg()
  LOCAL nPos  := PDFviewWnd.Files.VALUE[1]
  LOCAL cFile := PDFviewWnd.Files.CellEx(nPos, F_NAME)
  LOCAL cAttr := PDFviewWnd.Files.CellEx(nPos, F_ATTR)
  LOCAL lDir
  LOCAL cName
  LOCAL cExt

  IF ("K" $ cAttr) .or. (cFile == "..")
    RETURN NIL
  ENDIF

  lDir  := ("D" $ cAttr)

  IF lDir
    cName := cFile
    cExt  := ""
  ELSE
    cName := HB_fNameName(cFile)
    cExt  := HB_fNameExt(cFile)
  ENDIF

  DEFINE WINDOW RenameFileWnd;
    WIDTH  420 + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;
    HEIGHT 181 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(If(lDir, LS_RenameDir, LS_RenameFile));
    MODAL;
    NOSIZE

    DEFINE LABEL PathLabel
      ROW    10
      COL    10
      WIDTH  80
      HEIGHT 13
      VALUE  LangStr(LS_Path) + ":"
    END LABEL

    DEFINE TEXTBOX PathTBox
      ROW      25
      COL      10
      WIDTH    400
      HEIGHT   21
      VALUE    scFileDir
      READONLY .T.
      TABSTOP  .F.
      DISABLEDBACKCOLOR ColorArray(GetSysColor(15 /*COLOR_BTNFACE*/))
      ONGOTFOCUS  SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .T.)
      ONLOSTFOCUS SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .F.)
      ONENTER     Files_Rename(cFile, cExt, lDir)
    END TEXTBOX

    DEFINE LABEL NameLabel
      ROW    56
      COL    10
      WIDTH  80
      HEIGHT 13
      VALUE  LangStr(LS_Name) + ":"
    END LABEL

    DEFINE TEXTBOX NameTBox
      ROW      71
      COL      10
      WIDTH    400
      HEIGHT   21
      VALUE    cFile
      READONLY .T.
      TABSTOP  .F.
      DISABLEDBACKCOLOR ColorArray(GetSysColor(15 /*COLOR_BTNFACE*/))
      ONGOTFOCUS  SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .T.)
      ONLOSTFOCUS SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .F.)
      ONENTER     Files_Rename(cFile, cExt, lDir)
    END TEXTBOX

    DEFINE LABEL NewNameLabel
      ROW    102
      COL    10
      WIDTH  80
      HEIGHT 13
      VALUE  LangStr(LS_NewName) + ":"
    END LABEL

    DEFINE TEXTBOX NewNameTBox
      ROW    117
      COL    10
      WIDTH  If(lDir, 400, 375)
      HEIGHT 21
      VALUE  cName
      ONGOTFOCUS  SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .T.)
      ONLOSTFOCUS SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .F.)
      ONCHANGE    If(IsControlDefined(RenameButton, RenameFileWnd), ((RenameFileWnd.RenameButton.ENABLED := (! (This.VALUE == ""))), SetDefPushButton(RenameFileWnd.RenameButton.HANDLE, .T.)), NIL)
      ONENTER     Files_Rename(cFile, cExt, lDir)
    END TEXTBOX

    IF ! lDir
      DEFINE LABEL ExtLabel
        ROW    120
        COL    385
        WIDTH  25
        HEIGHT 13
        VALUE  cExt
      END LABEL
    ENDIF

    DEFINE BUTTON RenameButton
      ROW     148
      COL     200
      WIDTH   100
      HEIGHT  23
      CAPTION LangStr(LS_Rename)
      ACTION  Files_Rename(cFile, cExt, lDir)
    END BUTTON

    DEFINE BUTTON CancelButton
      ROW     148
      COL     310
      WIDTH   100
      HEIGHT  23
      CAPTION LangStr(LS_Cancel)
      ACTION  RenameFileWnd.RELEASE
      ONLOSTFOCUS SetDefPushButton(This.HANDLE, .F.)
    END BUTTON
  END WINDOW

  ON KEY F1 OF RenameFileWnd ACTION NIL

  RenameFileWnd.CenterIn(PDFviewWnd)
  RenameFileWnd.ACTIVATE

RETURN NIL


FUNCTION Files_Rename(cFile, cExt, lDir)
  LOCAL cNewName := RenameFileWnd.NewNameTBox.VALUE
  LOCAL nPos1
  LOCAL nPos2
  LOCAL cSourceName
  LOCAL cTargetName
  LOCAL nError

  IF cNewName == ""
    RETURN NIL
  ENDIF

  IF ((cNewName += cExt) == cFile)
    RenameFileWnd.RELEASE
    RETURN NIL
  ENDIF

  IF ! FileNameValid(cNewName, @nPos1, @nPos2)
    MsgWin(LangStr(LS_IncorrectName), RenameFileWnd.TITLE)
    RenameFileWnd.NewNameTBox.SETFOCUS
    HMG_EditControlSetSel(RenameFileWnd.NewNameTBox.HANDLE, nPos1 - 1, nPos2)
    RETURN NIL
  ENDIF

  cSourceName := scFileDir + cFile
  cTargetName := scFileDir + cNewName

  IF fRename(cSourceName, cTargetName) == F_ERROR
    nError := fError()

    IF nError == 32 /*ERROR_SHARING_VIOLATION*/
      MsgWin(LangStr(LS_CantRename) + CRLF + LangStr(If(lDir, LS_DirInUse, LS_FileInUse)), RenameFileWnd.TITLE)
      RETURN NIL
    ELSEIF (nError == 5 /*ERROR_ACCESS_DENIED*/) .and. HB_fNameExists(cTargetName)
      IF lDir
        MsgWin(LangStr(LS_CantRename) + CRLF + If(HB_DirExists(cTargetName), LangStr(LS_DirExists), LangStr(LS_FileExists)), RenameFileWnd.TITLE)
        RETURN NIL
      ENDIF

      IF HB_FileExists(cTargetName)
        IF MsgWin(LangStr(LS_FileOverwrite) + CRLF2 + cTargetName, RenameFileWnd.TITLE, {LangStr(LS_Yes), LangStr(LS_Cancel)}, 2) != 1
          RETURN NIL
        ENDIF

        IF ! HB_FileDelete(cTargetName, "HRS")
          MsgWin(LangStr(LS_CantDelete) + CRLF2 + cTargetName, RenameFileWnd.TITLE)
          RETURN NIL
        ENDIF

        IF fRename(cSourceName, cTargetName) == F_ERROR
          MsgWin(LangStr(LS_CantRename), RenameFileWnd.TITLE)
          RETURN NIL
        ENDIF
      ELSE
        MsgWin(LangStr(LS_CantRename) + CRLF + LangStr(LS_DirExists), RenameFileWnd.TITLE)
        RETURN NIL
      ENDIF
    ELSE
      MsgWin(LangStr(LS_CantRename), RenameFileWnd.TITLE)
      RETURN NIL
    ENDIF
  ENDIF

  Files_Refresh(cNewName)
  RenameFileWnd.RELEASE

RETURN NIL


FUNCTION Files_Delete()
  LOCAL nPos  := PDFviewWnd.Files.VALUE[1]
  LOCAL cFile := PDFviewWnd.Files.CellEx(nPos, F_NAME)
  LOCAL cAttr := PDFviewWnd.Files.CellEx(nPos, F_ATTR)
  LOCAL cFileName
  LOCAL lDir
  LOCAL nError

  IF ("K" $ cAttr) .or. (cFile == "..")
    RETURN NIL
  ENDIF

  cFileName := scFileDir + cFile
  lDir      := ("D" $ cAttr)

  IF MsgWin(cFileName, LangStr(If(lDir, LS_DeleteDir, LS_DeleteFile)), {LangStr(LS_Delete), LangStr(LS_Cancel)}, 2) != 1
    RETURN NIL
  ENDIF

  IF lDir
    nError := HB_DirDelete(cFileName)

    IF nError == 32 /*ERROR_SHARING_VIOLATION*/
      MsgWin(cFileName + CRLF2 + LangStr(LS_CantDelete) + " " + LangStr(LS_DirInUse), LangStr(LS_DeleteDir))
    ELSEIF nError == 145 /*ERROR_DIR_NOT_EMPTY*/
      IF MsgWin(cFileName + CRLF2 + LangStr(LS_DirNotEmpty) + " " + LangStr(LS_DeleteAllContent), LangStr(LS_DeleteDir), {LangStr(LS_Delete), LangStr(LS_Cancel)}, 2) == 1
        IF ! HB_DirRemoveAll(cFileName)
          MsgWin(cFileName + CRLF2 + LangStr(LS_CantDeleteAll), LangStr(LS_DeleteDir))
          FileOpen()
        ENDIF
      ENDIF
    ENDIF
  ELSE
    IF ! HB_FileDelete(cFileName, "HRS")
      MsgWin(cFileName + CRLF2 + LangStr(LS_CantDelete) + " " + LangStr(LS_FileInUse), LangStr(LS_DeleteFile))
    ENDIF
  ENDIF

  Files_Refresh()

RETURN NIL


FUNCTION Files_Properties()

  FileProperties(scFileDir + PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME))

RETURN NIL


FUNCTION Tabs_EventHandler()
  STATIC nTabDrag  := 0
  STATIC lTracking := .F.
  LOCAL  nHWnd     := EventHWND()
  LOCAL  nMsg      := EventMSG()
  LOCAL  nWParam   := EventWPARAM()
  LOCAL  nLParam   := EventLPARAM()
  LOCAL  nTabDrop
  LOCAL  cFile

  SWITCH nMsg
    CASE WM_RBUTTONUP
      TabChange(Tab_HitTest(nHWnd, nLParam))
      Tabs_Menu(.T.)
      RETURN 0
  
    CASE WM_LBUTTONDBLCLK
    CASE WM_MBUTTONDOWN
      TabClose(Tab_HitTest(nHWnd, nLParam), .T.)
      RETURN 0

    CASE WM_LBUTTONDOWN
      IF (nWParam == MK_LBUTTON) .and. (Len(saTab) > 1)
        TabChange(Tab_HitTest(nHWnd, nLParam))
        HMG_MouseClearBuffer()

        // drag and drop is initialized with negative value of nTabDrag
        // if next message is WM_MOUSEMOVE, nTabDrag will be changed to positive
        nTabDrag := -Tab_HitTest(nHWnd, nLParam)
        SetCapture(nHWnd)
      ENDIF
      EXIT

    CASE WM_LBUTTONUP
      IF nTabDrag != 0
        nTabDrop := Tab_HitTest(nHWnd, nLParam)
        TabMove(nTabDrag, nTabDrop)
        nTabDrag := 0
        ReleaseCapture()
        SetCursorShape(IDC_ARROW)
      ENDIF
      EXIT

    CASE WM_MOUSEMOVE
      nTabDrop := Tab_HitTest(nHWnd, nLParam)

      IF nWParam == MK_LBUTTON
        IF nTabDrag < 0
          nTabDrag := -nTabDrag
        ELSEIF nTabDrag > 0
          IF (nTabDrop == nTabDrag) .or. (nTabDrop == 0)
            SetCursorShape(IDC_NO)
          ELSE
            SetCursorShape("CurDragDrop")
          ENDIF
        ENDIF
      ELSEIF nTabDrop > 0
        cFile := HB_fNameName(Sumatra_FileName(PanelName(saTab[nTabDrop])))

        IF PDFviewWnd.Tabs.Caption(nTabDrop) == cFile
          PDFviewWnd.Tabs.TOOLTIP := ""
        ELSEIF ! (PDFviewWnd.Tabs.TOOLTIP == cFile)
          PDFviewWnd.Tabs.TOOLTIP := cFile
        ENDIF

        IF ! lTracking
          lTracking := TrackMouseEvent(nHWnd)
        ENDIF
      ENDIF
      EXIT

    CASE WM_MOUSELEAVE
      PDFviewWnd.Tabs.TOOLTIP := ""
      lTracking := .F.
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION Tabs_Menu(lMouse)
  LOCAL lPdfOpened  := (Sumatra_FrameHandle(PanelName()) != 0)
  LOCAL nHMenu      := CreatePopupMenu()
  LOCAL nHMenuMove  := CreatePopupMenu()
  LOCAL nHMenuClose := CreatePopupMenu()
  LOCAL nHMenuOpen  := CreatePopupMenu()
  LOCAL nRow, nCol
  LOCAL nCmd
  LOCAL n

  IF lPdfOpened
    FOR n := 1 TO Len(saTab)
      AppendMenuString(nHMenu, n, Sumatra_FileName(PanelName(saTab[n])) + If(n <= 9, e"\tAlt+" + HB_NtoS(n), If(n == Len(saTab), e"\tAlt+End", "")))
    NEXT

    xCheckMenuItem(nHMenu, PDFviewWnd.Tabs.VALUE)
    AppendMenuSeparator(nHMenu)

    IF Len(saTab) > 1
      AppendMenuString(nHMenuMove, 10001, LangStr(LS_Left)      + e"\tShift+Alt+<-")
      AppendMenuString(nHMenuMove, 10002, LangStr(LS_Right)     + e"\tShift+Alt+->")
      AppendMenuString(nHMenuMove, 10003, LangStr(LS_Beginning) + e"\tShift+Alt+-Home")
      AppendMenuString(nHMenuMove, 10004, LangStr(LS_End)       + e"\tShift+Alt+End")
      AppendMenuPopup(nHMenu, nHMenuMove, LangStr(LS_MoveTab))

      IF PDFviewWnd.Tabs.VALUE == 1
        xDisableMenuItem(nHMenu, 10001)
        xDisableMenuItem(nHMenu, 10003)
      ENDIF

      IF PDFviewWnd.Tabs.VALUE == Len(saTab)
        xDisableMenuItem(nHMenu, 10002)
        xDisableMenuItem(nHMenu, 10004)
      ENDIF
    ENDIF

    AppendMenuString(nHMenuClose, 10005, LangStr(LS_CurrDoc)     + e"\tCtrl+W")
    AppendMenuString(nHMenuClose, 10006, LangStr(LS_DupDoc)      + e"\tAlt+W")
    AppendMenuString(nHMenuClose, 10007, LangStr(LS_AllDup)      + e"\tShift+Alt+W")
    AppendMenuString(nHMenuClose, 10008, LangStr(LS_AllInactive) + e"\tCtrl+Alt+W")
    AppendMenuString(nHMenuClose, 10009, LangStr(LS_AllDoc)      + e"\tCtrl+Shift+W")
    AppendMenuPopup(nHMenu, nHMenuClose, LangStr(LS_Close))

    IF Len(saTab) <= 1
      xDisableMenuItem(nHMenu, 10006)
      xDisableMenuItem(nHMenu, 10007)
      xDisableMenuItem(nHMenu, 10008)
      xDisableMenuItem(nHMenu, 10009)
    ENDIF
  ENDIF

  IF ! Empty(saTabClosed)
    AppendMenuString(nHMenu, 10010, LangStr(LS_RestoreLastTab) + e"\tCtrl+Shift+T")
  ENDIF

  IF lPdfOpened
    AppendMenuSeparator(nHMenu)
    AppendMenuString(nHMenuOpen, 10011, LangStr(LS_OpenInNewTab) + e"...\tCtrl+O")
    AppendMenuString(nHMenuOpen, 10012, LangStr(LS_OpenInCurTab) + e"...\tCtrl+Shift+O")
    AppendMenuPopup(nHMenu, nHMenuOpen, LangStr(LS_NewDocument))
  ELSE
    IF ! Empty(saTabClosed)
      AppendMenuSeparator(nHMenu)
    ENDIF

    AppendMenuString(nHMenu, 10011, LangStr(LS_NewDocument) + e"...\tCtrl+O")
  ENDIF

  IF lMouse
    HMG_GetCursorPos(NIL, @nRow, @nCol)
  ELSE
    nRow := GetWindowRow(PDFviewWnd.Tabs.HANDLE) + GetWindowHeight(PDFviewWnd.Tabs.HANDLE)
    nCol := GetWindowCol(PDFviewWnd.Tabs.HANDLE)
  ENDIF

  slMenuActive := .T.
  PDFview_SetOnKey(.F.)

  nCmd := TrackPopupMenu2(nHMenu, 0x0180 /*TPM_NONOTIFY|TPM_RETURNCMD*/, nRow, nCol, PDFviewWnd.HANDLE)

  DestroyMenu(nHMenu)
  DestroyMenu(nHMenuMove)
  DestroyMenu(nHMenuClose)
  DestroyMenu(nHMenuOpen)
  PDFview_SetOnKey(.T.)
  slMenuActive := .F.

  IF nCmd > 0
    IF nCmd <= 10000
      TabChange(nCmd)
    ELSE
      SWITCH nCmd
        CASE 10001
          TabMove(-1)
          EXIT
        CASE 10002
          TabMove(1)
          EXIT
        CASE 10003
          TabMove(-2)
          EXIT
        CASE 10004
          TabMove(1)
          EXIT
        CASE 10005
          TabClose(0, .T.)
          EXIT
        CASE 10006
          TabCloseAll(3)
          EXIT
        CASE 10007
          TabCloseAll(4)
          EXIT
        CASE 10008
          TabCloseAll(2)
          EXIT
        CASE 10009
          TabCloseAll(1)
          EXIT
        CASE 10010
          TabRestore()
          EXIT
        CASE 10011
          FileGetAndOpen(.T.)
          EXIT
        CASE 10012
          FileGetAndOpen(.F.)
          EXIT
      ENDSWITCH
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Status_Show()

  slStatusBar := ! slStatusBar

  PDFviewWnd.STATUSBAR.VISIBLE := slStatusBar

  PDFview_Resize(.T.)
  Status_SetFile()

RETURN NIL


FUNCTION Status_SetFile()
  LOCAL cFile := Sumatra_FileName(PanelName())
  LOCAL cTabCaption
  LOCAL nPage
  LOCAL nCount

  IF Empty(cFile)
    PDFviewWnd.Tabs.Caption(PDFviewWnd.Tabs.VALUE) := cFile
    PDFviewWnd.TITLE := scProgName

    IF slStatusBar
      PDFviewWnd.STATUSBAR.Item(1) := cFile
    ENDIF
  ELSE
    cTabCaption := HB_fNameName(cFile)
    nPage       := Sumatra_PageNumber(PanelName())
    nCount      := Sumatra_PageCount(PanelName())

    IF (snTab_W > 0) .and. (HMG_Len(cTabCaption) > snTab_W)
      cTabCaption := HB_UTF8Left(cTabCaption, snTab_W) + "..."
    ENDIF

    PDFviewWnd.Tabs.Caption(PDFviewWnd.Tabs.VALUE) := cTabCaption

    IF slStatusBar
      PDFviewWnd.TITLE := HB_fNameNameExt(cFile)
      PDFviewWnd.STATUSBAR.Item(1) := cFile
      PDFviewWnd.STATUSBAR.Item(2) := If(nCount == 0, "", LangStr(LS_Page, .T.) + ": " + HB_NtoS(nPage) + "/" + HB_NtoS(nCount))
    ELSE
      PDFviewWnd.TITLE := HB_fNameNameExt(cFile) + If(nCount == 0, "", " [" + HB_NtoS(nPage) + "/" + HB_NtoS(nCount) + "]")
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Status_SetPage(lForce)
  STATIC nPage   := 0
  STATIC nCount  := 0
  LOCAL  nPage1  := Sumatra_PageNumber(PanelName())
  LOCAL  nCount1 := Sumatra_PageCount(PanelName())
  LOCAL  cFile

  IF lForce .or. (nPage != nPage1) .or. (nCount != nCount1)
    nPage  := nPage1
    nCount := nCount1

    IF slStatusBar
      PDFviewWnd.STATUSBAR.Item(2) := If(nCount == 0, "", LangStr(LS_Page, .T.) + ": " + HB_NtoS(nPage) + "/" + HB_NtoS(nCount))
    ELSE
      cFile := Sumatra_FileName(PanelName())
      PDFviewWnd.TITLE := If(Empty(cFile), scProgName, HB_fNameNameExt(cFile)) + If(nCount == 0, "", " [" + HB_NtoS(nPage) + "/" + HB_NtoS(nCount) + "]")
    ENDIF
  ENDIF

  RELEASE MEMORY

RETURN NIL


FUNCTION PanelNew()
  LOCAL nPanel
  LOCAL cPanel
  LOCAL nHWnd

  IF (Len(saTab) == 1) .and. saPanel[saTab[1]]
    nPanel := saTab[1]
  ELSE
    nPanel := HB_aScan(saPanel, .T.)
  ENDIF

  IF nPanel == 0
    aAdd(saPanel, .T.)

    nPanel := Len(saPanel)
    cPanel := PanelName(nPanel)

    DEFINE WINDOW &cPanel;
      PARENT   PDFviewWnd;
      ROW      0xFFFF;
      COL      0xFFFF;
      WIDTH    0;
      HEIGHT   0;
      PANEL;
      VISIBLE  .F.;
      ON PAINT Sumatra_FrameRedraw(cPanel)
    END WINDOW

    nHWnd := GetFormHandle(cPanel)

    SetClassLongPtr(nHWnd, -26 /*GCL_STYLE*/, HB_BitOr(GetClassLongPtr(nHWnd, -26 /*GCL_STYLE*/), 0x0008 /*CS_DBLCLKS*/))
    ChangeWindowMessageFilter(nHWnd, 74 /*WM_COPYDATA*/, 1 /*MSGFLT_ALLOW*/)
  ENDIF

RETURN nPanel


FUNCTION PanelName(nPanel)

  IF ! HB_IsNumeric(nPanel)
    nPanel := saTab[PDFviewWnd.Tabs.VALUE]
  ENDIF

  IF (nPanel > 0) .and. (nPanel <= Len(saPanel))
    RETURN "P" + HB_NtoS(nPanel)
  ENDIF

RETURN ""


FUNCTION PanelShow(nPanel, lShow)
  LOCAL nHWnd := GetFormHandle(PanelName(nPanel))

  IF lShow
    ShowWindow(nHWnd)
  ELSE
    SetWindowPos(nHWnd, 0, 0xFFFF, 0xFFFF, 0, 0, 0x94 /*SWP_HIDEWINDOW|SWP_NOACTIVATE|SWP_NOZORDER*/)
  ENDIF

RETURN NIL


FUNCTION TabNew(nTab, nPanel)

  IF nTab < 0
    SWITCH snTabNew
      CASE 1
        nTab := PDFviewWnd.Tabs.VALUE
        EXIT
      CASE 2
        nTab := PDFviewWnd.Tabs.VALUE + 1
        EXIT
      CASE 3
        nTab := 1
        EXIT
      OTHERWISE
        nTab := Len(saTab) + 1
    ENDSWITCH
  ELSEIF nTab > Len(saTab)
    nTab := Len(saTab) + 1
  ENDIF

  HB_aIns(saTab, nTab, nPanel, .T.)
  PDFviewWnd.Tabs.AddPage(nTab, "")

  PDFviewWnd.Tabs.VALUE := nTab

RETURN nTab


FUNCTION TabChange(nTabNew)
  LOCAL nTabCurr
  LOCAL lFileFocus

  IF Len(saTab) > 1
    nTabCurr := PDFviewWnd.Tabs.VALUE

    IF nTabNew == 0 //last tab
      nTabNew := Len(saTab)
    ELSEIF nTabNew == -1 //next tab
      IF nTabCurr == Len(saTab)
        nTabNew := 1
      ELSE
        nTabNew := nTabCurr + 1
      ENDIF
    ELSEIF nTabNew == -2 //previous tab
      IF nTabCurr == 1
        nTabNew := Len(saTab)
      ELSE
        nTabNew := nTabCurr - 1
      ENDIF
    ENDIF

    IF (nTabNew != nTabCurr) .and. (nTabNew <= Len(saTab))
      lFileFocus := (GetFocus() == PDFviewWnd.Files.HANDLE)
      PDFviewWnd.Tabs.VALUE := nTabNew

      PanelShow(saTab[nTabCurr], .F.)
      PanelShow(saTab[nTabNew],  .T.)
      PDFview_Resize(.F.)
      Status_SetFile()

      IF slTabGoToFile
        Files_GoTo()
      ENDIF

      SetFocus(If(lFileFocus, PDFviewWnd.Files.HANDLE, Sumatra_FrameHandle(PanelName(saTab[nTabNew]))))
    ENDIF
  ENDIF

RETURN NIL


/*
  if nTab2 is not numeric, nTab1 can be:
  -1 - move left
   1 - move right
  -2 - move at beginning
   2 - move at end
*/
FUNCTION TabMove(nTab1, nTab2)
  LOCAL cCaption
  LOCAL n

  IF ! HB_IsNumeric(nTab2)
    nTab2 := 0

    SWITCH nTab1
      CASE -1
      CASE 1
        nTab2 := PDFviewWnd.Tabs.VALUE + nTab1
        EXIT
      CASE -2
        nTab2 := 1
        EXIT
      CASE 2
        nTab2 := Len(saTab)
        EXIT
    ENDSWITCH

    nTab1 := PDFviewWnd.Tabs.VALUE
  ENDIF

  IF (nTab1 > 0) .and. (nTab2 > 0) .and. (nTab1 != nTab2) .and. (nTab2 <= Len(saTab))
    HB_aIns(saTab, nTab2 + If(nTab1 < nTab2, 1, 0), saTab[nTab1], .T.)
    HB_aDel(saTab, nTab1 + If(nTab1 < nTab2, 0, 1), .T.)

    cCaption := PDFviewWnd.Tabs.Caption(nTab1)

    IF nTab1 < nTab2
      FOR n := nTab1 TO (nTab2 - 1)
        PDFviewWnd.Tabs.Caption(n) := PDFviewWnd.Tabs.Caption(n + 1)
      NEXT
    ELSE
      FOR n := nTab1  TO (nTab2 + 1) STEP -1
        PDFviewWnd.Tabs.Caption(n) := PDFviewWnd.Tabs.Caption(n - 1)
      NEXT
    ENDIF

    PDFviewWnd.Tabs.Caption(nTab2) := cCaption
    PDFviewWnd.Tabs.VALUE := nTab2
  ENDIF

RETURN NIL


FUNCTION TabClose(nTab, lRemember)
  LOCAL lFileFocus := (GetFocus() == PDFviewWnd.Files.HANDLE)
  LOCAL nTabCurr   := PDFviewWnd.Tabs.VALUE
  LOCAL cPanel
  LOCAL cFile
  LOCAL nPage

  IF nTab == 0
    nTab := nTabCurr
  ENDIF

  cPanel := PanelName(saTab[nTab])
  saPanel[saTab[nTab]] := .T.

  IF nTab == nTabCurr
    SumatraGetSettings()
  ENDIF

  IF lRemember
    cFile := Sumatra_FileName(cPanel)
    nPage := Sumatra_PageNumber(cPanel)

    FileRecentAdd(cFile, nPage)
    HB_aIns(saTabClosed, 1, {nTab, cFile, nPage}, (Len(saTabClosed) < 100))
  ENDIF

  Sumatra_FileClose(cPanel, .T.)

  IF Len(saTab) > 1
    IF nTab == nTabCurr
      PanelShow(saTab[nTab], .F.)

      IF nTab == Len(saTab)
        --nTabCurr
      ENDIF
    ELSEIF nTab < nTabCurr
      --nTabCurr
    ENDIF

    HB_aDel(saTab, nTab, .T.)
    PDFviewWnd.Tabs.DeletePage(nTab)
    PDFviewWnd.Tabs.VALUE := nTabCurr

    PanelShow(saTab[nTabCurr], .T.)

    IF slTabGoToFile
      Files_GoTo()
    ENDIF
  ENDIF

  PDFviewWnd.Tabs.VISIBLE := (! saPanel[saTab[1]])

  PDFview_Resize(.F.)
  Status_SetFile()

  IF lFileFocus .or. (Sumatra_FrameHandle(PanelName(saTab[nTabCurr])) == 0)
    PDFviewWnd.Files.SETFOCUS
  ELSE
    SetFocus(Sumatra_FrameHandle(PanelName(saTab[nTabCurr])))
  ENDIF

RETURN NIL


/*
  TabCloseAll([nAction])
    nAction:
    0 - close all empty
    1 - close all
    2 - close all inactive
    3 - close duplicates of current document
    4 - close all duplicates
*/
FUNCTION TabCloseAll(nAction)
  LOCAL nTabCurr := PDFviewWnd.Tabs.VALUE
  LOCAL nTabs    := Len(saTab)
  LOCAL cFile    := Sumatra_FileName(PanelName(saTab[nTabCurr]))
  LOCAL aTabClose
  LOCAL n, k

  IF nAction < 4
    FOR n := nTabs TO 1 STEP -1
      IF (nAction == 0) .and. (Sumatra_FrameHandle(PanelName(saTab[n])) == 0) .or. ;
         (nAction == 1) .or. ;
         (nAction == 2) .and. (n != nTabCurr) .or. ;
         (nAction == 3) .and. (n != nTabCurr) .and. (cFile == Sumatra_FileName(PanelName(saTab[n])))
        TabClose(n, (nAction != 0))
      ENDIF
    NEXT
  ELSE
    aTabClose := {}

    FOR n := 1 TO nTabs
      IF (n != nTabCurr) .and. (HMG_StrCmp(Sumatra_FileName(PanelName(saTab[n])), cFile, .F.) == 0)
        aAdd(aTabClose, n)
      ENDIF
    NEXT

    FOR k := 1 TO nTabs
      IF (k != nTabCurr) .and. (HB_aScan(aTabClose, k) == 0)
        cFile := Sumatra_FileName(PanelName(saTab[k]))

        FOR n := (k + 1) TO nTabs
          IF HMG_StrCmp(Sumatra_FileName(PanelName(saTab[n])), cFile, .F.) == 0
            aAdd(aTabClose, n)
          ENDIF
        NEXT
      ENDIF
    NEXT

    IF ! Empty(aTabClose)
      aSort(aTabClose)

      FOR n := Len(aTabClose) TO 1 STEP -1
        TabClose(aTabClose[n], .T.)
      NEXT
    ENDIF
  ENDIF

RETURN NIL


FUNCTION TabRestore()
  LOCAL nPos := HB_aScan(saTabClosed, { |aTab| HB_FileExists(aTab[2]) })
  LOCAL n

  IF nPos == 0
    aSize(saTabClosed, 0)
    RETURN .F.
  ENDIF

  FOR n := (nPos - 1) TO 1 STEP -1
    HB_aDel(saTabClosed, n, .T.)
  NEXT

  IF FileOpen(saTabClosed[1][2], saTabClosed[1][3], saTabClosed[1][1], .T.)
    IF slTabGoToFile
      Files_GoTo()
    ENDIF

    HB_aDel(saTabClosed, 1, .T.)
    RETURN .T.
  ENDIF

RETURN .F.


FUNCTION FileOpen(cFile, nPage, nTab, lForceOpen)
  LOCAL lFilesPanel := .T.
  LOCAL lFileFocus
  LOCAL cSumatraExe
  LOCAL cRecentFile
  LOCAL nRecentPage
  LOCAL nPanel
  LOCAL n

  IF Empty(cFile)
    cFile := PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME)

    IF "D" $ PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_ATTR)
      IF "K" $ PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_ATTR)
        IF VolSerial(DirSepAdd(cFile)) == -1
          MsgWin(cFile + CRLF2 + LangStr(LS_NoDisk))
        ELSE
          scFileDir := DirSepAdd(cFile)
          cFile     := ".."
        ENDIF
      ELSE
        IF cFile == ".."
          IF HMG_Len(scFileDir) == 3
            cFile := DirSepDel(scFileDir)
          ELSE
            cFile := HB_FNameNameExt(DirSepDel(scFileDir))
          ENDIF
          scFileDir := DirParent(scFileDir)
        ELSE
          scFileDir := DirSepAdd(scFileDir + cFile)
          cFile     := ".."
        ENDIF
      ENDIF

      Files_Refresh(cFile)
      RETURN .F.
    ENDIF

    cFile := scFileDir + cFile
  ELSE
    lFilesPanel := .F.
  ENDIF

  HB_Default(@nPage, 0)
  HB_Default(@lForceOpen, .F.)

  IF slSingleOpenPDF .and. (! lForceOpen)
    IF HMG_StrCmp(cFile, Sumatra_FileName(PanelName()), .F.) == 0
      IF nPage < 0
        Sumatra_PageGoTo(PanelName())
      ENDIF

      RETURN .T.
    ENDIF

    FOR n := 1 TO Len(saTab)
      IF HMG_StrCmp(cFile, Sumatra_FileName(PanelName(saTab[n])), .F.) == 0
        TabChange(n)

        IF nPage < 0
          Sumatra_PageGoTo(PanelName())
        ENDIF

        RETURN .T.
      ENDIF
    NEXT
  ENDIF

  IF nPage == 0
    IF HMG_StrCmp(cFile, Sumatra_FileName(PanelName()), .F.) == 0
      nPage := Sumatra_PageNumber(PanelName())
    ELSE
      nPage := FileRecentGetPage(cFile)
    ENDIF
  ELSEIF nPage < 0
    nPage := InputPageNum()

    IF HB_IsNIL(nPage)
      RETURN .F.
    ENDIF
  ENDIF

  SumatraGetSettings()

  lFileFocus  := If(slFilesPanel, (GetFocus() == PDFviewWnd.Files.HANDLE), .F.)
  cSumatraExe := "SumatraPDF.exe"

  IF Empty(nTab)
    nPanel := saTab[PDFviewWnd.Tabs.VALUE]
  ELSE
    nPanel := PanelNew()
  ENDIF

  IF nPanel == saTab[PDFviewWnd.Tabs.VALUE]
    cRecentFile := Sumatra_FileName(PanelName())
    nRecentPage := Sumatra_PageNumber(PanelName())
  ELSE
    PanelShow(nPanel, .T.)
  ENDIF

  nPage := Sumatra_FileOpen(PanelName(nPanel), cFile, nPage, snZoom, NIL, slBookmarks, slToolBar, scLang, If(Empty(scSumatraDir), HB_DirBase(), scSumatraDir) + cSumatraExe)

  SWITCH nPage
    CASE -1
      //MsgWin("Panel window is not defined!")
      RETURN .F.
    CASE -2
    CASE -4
    CASE -5
      IF nPanel != saTab[PDFviewWnd.Tabs.VALUE]
        PanelShow(nPanel, .F.)
      ENDIF

      IF nPage == -2
        MsgWin(If(Empty(scSumatraDir), HB_DirBase(), DirSepAdd(TrueName(scSumatraDir))) + cSumatraExe + CRLF2 + LangStr(LS_NoFile) + CRLF + LangStr(LS_SetPathTo) + " " + cSumatraExe + ".")
      ELSE
        MsgWin(LangStr(LS_InvalidVersion) + CRLF + LangStr(LS_UseVersion) + If(HB_Version(HB_VERSION_BITWIDTH) == 32, ", 32-bit.", "."))
      ENDIF

      PDFviewOptions(1)
      RETURN .F.
    CASE -3
      IF nPanel != saTab[PDFviewWnd.Tabs.VALUE]
        PanelShow(nPanel, .F.)
      ENDIF

      MsgWin(cFile + CRLF2 + LangStr(LS_NoFile) + If(lFilesPanel, CRLF + LangStr(LS_ListRefresh), ""))

      IF lFilesPanel
        Files_Refresh("")
      ENDIF
      RETURN .F.
    OTHERWISE
      saPanel[nPanel] := .F.

      IF nPanel == saTab[PDFviewWnd.Tabs.VALUE]
        FileRecentAdd(cRecentFile, nRecentPage)
      ELSE
        PanelShow(NIL, .F.)
        TabNew(nTab, nPanel)
      ENDIF

      PDFviewWnd.Tabs.VISIBLE := (! saPanel[saTab[1]])
      PDFview_Resize(.F.)
      Status_SetFile()

      DoEvents()
      SetFocus(If(lFileFocus, PDFviewWnd.Files.HANDLE, Sumatra_FrameHandle(PanelName())))
  ENDSWITCH

RETURN .T.


FUNCTION FileGetAndOpen(lNewTab)
  LOCAL aFilter := {{"*.pdf", "*.pdf"}}
  LOCAL cDir
  LOCAL aFile
  LOCAL cFile
  LOCAL nFiles
  LOCAL nTabs
  LOCAL nTabCurr
  LOCAL n

  IF ! saPanel[saTab[PDFviewWnd.Tabs.VALUE]]
    cDir := HB_fNameDir(Sumatra_FileName(PanelName()))
  ELSE
    cDir := scFileDir
  ENDIF

  IF lNewTab
    aFile  := GetFile(aFilter, LangStr(LS_OpenInNewTab, .T.), cDir, .T., .T.)
    nFiles := Len(aFile)

    aSort(aFile, NIL, NIL, {|c1, c2| (HMG_StrCmp(c1, c2, .F.) < 0)})

    FOR n := 1 TO nFiles
      nTabs    := Len(saTab)
      nTabCurr := PDFviewWnd.Tabs.VALUE

      IF FileOpen(aFile[n], 0, -1)
        IF (nTabs == Len(saTab)) .and. (n < nFiles)
          TabChange(nTabCurr)
        ELSEIF slTabGoToFile
          Files_GoTo()
        ENDIF
      ELSE
        EXIT
      ENDIF
    NEXT
  ELSE
    cFile := GetFile(aFilter, LangStr(LS_OpenInCurTab, .T.), cDir, .F., .T.)

    IF (! Empty(cFile)) .and. FileOpen(cFile, 0, 0) .and. slTabGoToFile
      Files_GoTo()
    ENDIF
  ENDIF

RETURN NIL


/*
  nAction:
  -1 - previous
   1 - next
  -2 - first
   2 - last
*/
FUNCTION FileOpenFromDir(nAction)
  LOCAL cFileName := Sumatra_FileName(PanelName())
  LOCAL cFile
  LOCAL cDir
  LOCAL aDirectory
  LOCAL nPos

  IF Empty(cFileName)
    RETURN NIL
  ENDIF

  cFile      := HB_fNameNameExt(cFileName)
  cDir       := HB_fNameDir(cFileName)
  aDirectory := Directory(cDir + "*.pdf", "HS")

  aSort(aDirectory, NIL, NIL, { |a1, a2| (HMG_StrCmp(HB_fNameName(a1[F_NAME]), HB_fNameName(a2[F_NAME]), .F.) < 0) })

  nPos := HB_aScan(aDirectory, { |aFile| HMG_StrCmp(aFile[F_NAME], cFile, .F.) == 0 })

  IF Abs(nAction) == 1
    nPos += nAction
  ELSEIF nAction == -2
    nPos := If(nPos == 1, 0, 1)
  ELSE
    nPos := If(nPos == Len(aDirectory), 0, Len(aDirectory))
  ENDIF

  IF (nPos > 0) .and. (nPos <= Len(aDirectory))
    IF FileOpen(cDir + aDirectory[nPos][F_NAME], 0, 0, .T.) .and. slTabGoToFile
      Files_GoTo()
    ENDIF

    HMG_KeyboardClearBuffer()
  ENDIF

RETURN NIL


FUNCTION FilePrintDirectly(lFromPanel)
  LOCAL cFile
  LOCAL cDir
  LOCAL cSumatraExe
  LOCAL nError

  IF lFromPanel
    cFile := PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME)

    IF "D" $ PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_ATTR)
      RETURN NIL
    ENDIF

    cFile := scFileDir + cFile
  ELSE
    IF ! saPanel[saTab[PDFviewWnd.Tabs.VALUE]]
      cDir := HB_fNameDir(Sumatra_FileName(PanelName()))
    ELSE
      cDir := scFileDir
    ENDIF

    cFile := GetFile({{"*.pdf", "*.pdf"}}, LangStr(LS_PrintFile), cDir, .F., .T.)

    IF Empty(cFile)
      RETURN NIL
    ENDIF
  ENDIF

  cSumatraExe := "SumatraPDF.exe"
  nError      := Sumatra_FilePrintDirectly(cFile, scLang, If(Empty(scSumatraDir), HB_DirBase(), scSumatraDir) + cSumatraExe)

  SWITCH nError
    CASE -2
      MsgWin(If(Empty(scSumatraDir), HB_DirBase(), DirSepAdd(TrueName(scSumatraDir))) + cSumatraExe + CRLF2 + LangStr(LS_NoFile) + CRLF + LangStr(LS_SetPathTo) + " " + cSumatraExe + ".")
      PDFviewOptions(1)
      EXIT
    CASE -3
      MsgWin(cFile + CRLF2 + LangStr(LS_NoFile))
      EXIT
    CASE -4
    CASE -5
      MsgWin(LangStr(LS_InvalidVersion) + CRLF + LangStr(LS_UseVersion) + If(HB_Version(HB_VERSION_BITWIDTH) == 32, ", 32-bit.", "."))
      PDFviewOptions(1)
      EXIT
  ENDSWITCH

RETURN NIL


       //FileRecentAdd(cFile, [nPage], [cPass])
FUNCTION FileRecentAdd(cFile, nPage, cPass)
  LOCAL nPos

  IF (snRecentAmount > 0) .and. (! Empty(cFile))
    nPos := HB_aScan(saRecent, {|aFile| HMG_StrCmp(aFile[RECENTF_NAME], cFile, .F.) == 0})

    IF nPos > 0
      IF ! HB_IsNumeric(nPage)
        nPage := saRecent[nPos][RECENTF_PAGE]
      ENDIF

      IF ! HB_IsString(cPass)
        cPass := saRecent[nPos][RECENTF_PASS]
      ENDIF

      HB_aDel(saRecent, nPos, .T.)
    ENDIF

    HB_aIns(saRecent, 1, {cFile, If(HB_IsNumeric(nPage), nPage, 1), If(HB_IsString(cPass), cPass, "")}, (Len(saRecent) < snRecentAmount))
  ENDIF

RETURN NIL


FUNCTION FileRecentGetPage(cFile)
  LOCAL nPos := HB_aScan(saRecent, {|aFile| HMG_StrCmp(aFile[RECENTF_NAME], cFile, .F.) == 0})

RETURN If(nPos > 0, saRecent[nPos][RECENTF_PAGE], 1)


FUNCTION FileRecentGetPass(cFile)
  LOCAL nPos := HB_aScan(saRecent, {|aFile| HMG_StrCmp(aFile[RECENTF_NAME], cFile, .F.) == 0})

RETURN If(nPos > 0, saRecent[nPos][RECENTF_PASS], "")


/*
  SessionOpen(nAction, [aFile])
  nAction:
    1 - on start - open files passed from commad line
    2 - open files passed via WM_COPYDATA (aFile parameter is required)
    3 - on start - restore last session
    4 - open last session when program already is running
*/
FUNCTION SessionOpen(nAction, aFile)
  LOCAL cSumatraDir := If(Empty(scSumatraDir), HB_DirBase(), scSumatraDir)
  LOCAL cSumatraExe := "SumatraPDF.exe"
  LOCAL nCount      := 0
  LOCAL lFileFocus  := (GetFocus() == PDFviewWnd.Files.HANDLE)
  LOCAL nTabCurr    := PDFviewWnd.Tabs.VALUE
  LOCAL nPanel
  LOCAL nStart
  LOCAL nEnd
  LOCAL cFile
  LOCAL nPage
  LOCAL nHFrame
  LOCAL n

  IF (nAction == 4) .and. (! HB_FileExists(cSumatraDir + cSumatraExe))
    MsgWin(cSumatraDir + cSumatraExe + CRLF2 + LangStr(LS_NoFile) + CRLF + LangStr(LS_SetPathTo) + " " + cSumatraExe + ".")
    PDFviewOptions(1)
    RETURN .F.
  ENDIF

  SumatraGetSettings()

  IF (nAction == 1)
    nStart := 1
    nEnd   := HB_ArgC()
  ELSEIF (nAction == 2)
    nStart := 2
    nEnd   := Len(aFile)
  ELSEIF (nAction == 3) .and. slSessionRest .or. (nAction == 4)
    nStart := 2
    nEnd   := Len(saSession)
  ELSE
    nStart := 1
    nEnd   := 0
  ENDIF

  FOR n := nStart TO nEnd
    nPanel := PanelNew()

    IF nPanel != saTab[PDFviewWnd.Tabs.VALUE]
      PanelShow(nPanel, .T.)
    ENDIF

    IF (nAction == 1)
      cFile := HB_ArgV(n)

      IF HB_UTF8Left(cFile, 1) == "\"
        cFile := HB_UTF8Left(scDirStart, 2) + cFile
      ELSEIF ! (HB_UTF8SubStr(cFile, 2, 1) == ":")
        cFile := scDirStart + cFile
      ENDIF

      cFile := HB_PathNormalize(GetLongPathName(cFile))
      nPage := FileRecentGetPage(cFile)
    ELSEIF (nAction == 2)
      cFile := aFile[n]

      IF HB_UTF8Left(cFile, 1) == "\"
        cFile := HB_UTF8Left(aFile[1], 2) + cFile
      ELSEIF ! (HB_UTF8SubStr(cFile, 2, 1) == ":")
        cFile := aFile[1] + cFile
      ENDIF

      cFile := HB_PathNormalize(GetLongPathName(cFile))
      nPage := FileRecentGetPage(cFile)
    ELSE
      cFile := HB_PathNormalize(GetLongPathName(saSession[n][RECENTF_NAME]))
      nPage := saSession[n][RECENTF_PAGE]
    ENDIF

    IF Sumatra_FileOpen(PanelName(nPanel), cFile, nPage, snZoom, NIL, slBookmarks, slToolBar, scLang, cSumatraDir + cSumatraExe) >= 0
      ++nCount
      saPanel[nPanel] := .F.

      IF nPanel != saTab[PDFviewWnd.Tabs.VALUE]
        PanelShow(NIL, .F.)
        TabNew(Len(saTab) + 1, nPanel)
      ENDIF

      PDFviewWnd.Tabs.VISIBLE := (! saPanel[saTab[1]])
      PDFview_Resize(.F.)
      Status_SetFile()

      IF (nAction > 2) .and. (nCount <= saSession[1][RECENTF_PAGE])
        nTabCurr := PDFviewWnd.Tabs.VALUE
      ENDIF
    ELSE
      IF nPanel != saTab[PDFviewWnd.Tabs.VALUE]
        PanelShow(nPanel, .F.)
      ENDIF
    ENDIF
  NEXT

  IF nCount > 0
    IF (nAction > 2) .and. (nTabCurr != PDFviewWnd.Tabs.VALUE)
      TabChange(nTabCurr)
    ELSEIF slTabGoToFile
      Files_GoTo()
    ENDIF

    nHFrame := Sumatra_FrameHandle(PanelName())

    DoEvents()

    IF (nHFrame == 0)
      PDFviewWnd.Files.SETFOCUS
    ELSEIF slFilesPanel
      IF (nAction == 2) .or. (nAction == 4)
        IF lFileFocus
          PDFviewWnd.Files.SETFOCUS
        ELSE
          SetFocus(nHFrame)
        ENDIF
      ENDIF
    ELSE
      PostMessage(PDFviewWnd.HANDLE, 0x8000 /*WM_APP*/, 0, nHFrame)
    ENDIF
  ENDIF

RETURN (nCount > 0)


FUNCTION SessionReopen()
  LOCAL lFileFocus := (GetFocus() == PDFviewWnd.Files.HANDLE)
  LOCAL nTab       := 1
  LOCAL nTabCurr   := PDFviewWnd.Tabs.VALUE
  LOCAL nCount     := Len(saTab)
  LOCAL cFile
  LOCAL nPage
  LOCAL cPanel
  LOCAL nHFrame
  LOCAL n

  FOR n := 1 TO nCount
    TabChange(nTab)

    cPanel := PanelName()
    cFile  := Sumatra_FileName(cPanel)

    IF ! Empty(cFile)
      nPage := Sumatra_PageNumber(cPanel)

      SumatraGetSettings()

      nPage := Sumatra_FileOpen(cPanel, cFile, nPage, snZoom, NIL, slBookmarks, slToolBar, scLang, If(Empty(scSumatraDir), HB_DirBase(), scSumatraDir) + "SumatraPDF.exe")

      IF nPage >= 0
        ++nTab
      ELSE
        TabClose(nTab, .F.)

        IF nTab < nTabCurr
          --nTabCurr
        ENDIF
      ENDIF
    ENDIF
  NEXT

  IF nTabCurr > Len(saTab)
    nTabCurr := Len(saTab)
  ENDIF

  TabChange(nTabCurr)
  Status_SetPage(.T.)

  nHFrame := Sumatra_FrameHandle(PanelName())

  DoEvents()

  IF lFileFocus .or. (nHFrame == 0)
    PDFviewWnd.Files.SETFOCUS
  ELSE
    SetFocus(nHFrame)
  ENDIF

RETURN NIL


FUNCTION SumatraGetSettings()
  LOCAL cPanel := PanelName()
  LOCAL nHToolBar

  IF Sumatra_FrameHandle(cPanel) != 0
    IF Sumatra_PageCount(cPanel) > 0
      nHToolBar := Sumatra_ToolbarHandle(cPanel)

      IF HB_BitAnd(SendMessage(nHToolBar, 1042 /*TB_GETSTATE*/, Sumatra_Command(cPanel, IDT_VIEW_FIT_PAGE), 0), 0x01 /*TBSTATE_CHECKED*/) != 0
        snZoom := 2
      ELSEIF HB_BitAnd(SendMessage(nHToolBar, 1042 /*TB_GETSTATE*/, Sumatra_Command(cPanel, IDT_VIEW_FIT_WIDTH), 0), 0x01 /*TBSTATE_CHECKED*/) != 0
        snZoom := 4
      ENDIF
    ENDIF

    IF Sumatra_BookmarksExist(cPanel)
      slBookmarks := Sumatra_Bookmarks(cPanel)
    ENDIF

    slToolBar := Sumatra_Toolbar(cPanel)
  ENDIF

RETURN NIL


FUNCTION SumatraSetZoom(nZoomNew)

  IF Sumatra_PageCount(PanelName()) > 0
    snZoom := nZoomNew
    Sumatra_Zoom(PanelName(), snZoom)
  ENDIF

RETURN NIL


// for ErrorSys
FUNCTION SumatraCloseAll()
  LOCAL nPanel

  IF HB_IsArray(saTab)
    FOR EACH nPanel IN saTab
      Sumatra_FileClose(PanelName(nPanel), .F.)
    NEXT
  ENDIF

RETURN NIL


FUNCTION InputPageNum()
  LOCAL nPage

  DEFINE WINDOW InputPageWnd;
    WIDTH  230 + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;
    HEIGHT  74 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(LS_OpenFilePage);
    MODAL;
    NOSIZE

    DEFINE LABEL PageNumber
      ROW       13
      COL       45
      WIDTH     90
      HEIGHT    13
      ALIGNMENT RIGHT
      VALUE     LangStr(LS_PageNum)
    END LABEL

    DEFINE TEXTBOX Number
      ROW          10
      COL         140
      WIDTH        40
      HEIGHT       21
      VALUE         1
      MAXLENGTH     5
      RIGHTALIGN  .T.
      DATATYPE    NUMERIC
      ONGOTFOCUS  SetDefPushButton(InputPageWnd.OpenButton.HANDLE, .T.)
      ONLOSTFOCUS SetDefPushButton(InputPageWnd.OpenButton.HANDLE, .F.)
      ONENTER     ((nPage := InputPageWnd.Number.VALUE), InputPageWnd.RELEASE)
    END TEXTBOX

    DEFINE BUTTON OpenButton
      ROW     41
      COL     40
      WIDTH   70
      HEIGHT  23
      CAPTION LangStr(LS_Open)
      ACTION  ((nPage := InputPageWnd.Number.VALUE), InputPageWnd.RELEASE)
    END BUTTON

    DEFINE BUTTON CancelButton
      ROW      41
      COL     120
      WIDTH    70
      HEIGHT   23
      CAPTION LangStr(LS_Cancel)
      ACTION  InputPageWnd.RELEASE
    END BUTTON
  END WINDOW

  SetDefPushButton(InputPageWnd.OpenButton.HANDLE, .T.)
  C_Center(InputPageWnd.HANDLE, GetActiveWindow())

  ON KEY F1 OF InputPageWnd ACTION NIL

  InputPageWnd.ACTIVATE

  IF HB_IsNumeric(nPage) .and. (nPage < 1)
    nPage := 1
  ENDIF

RETURN nPage


FUNCTION RecentFiles()
  LOCAL lFileFocus := (GetFocus() == PDFviewWnd.Files.HANDLE)
  LOCAL aFile
  LOCAL nHFrame

  DEFINE WINDOW RecentWnd;
    WIDTH  snRecent_W;
    HEIGHT snRecent_H;
    TITLE  LangStr(LS_RecentFiles, .T.);
    MODAL;
    ON PAINT   PaintSizeGrip(RecentWnd.HANDLE);
    ON SIZE    Recent_Resize();
    ON RELEASE ((snRecent_W := RecentWnd.WIDTH), (snRecent_H := RecentWnd.HEIGHT), Recent_Amount(.F.))

    DEFINE GRID Files
      ROW            10
      COL            10
      HEADERS        {LangStr(LS_File, .T.), LangStr(LS_Page, .T.)}
      WIDTHS         {0, 65}
      JUSTIFY        {GRID_JTFY_LEFT, GRID_JTFY_RIGHT}
      CELLNAVIGATION .F.
      ONDBLCLICK     Recent_FileOpen(If(GetKeyState(VK_CONTROL) < 0, -1, 0), If(GetKeyState(VK_SHIFT) < 0, 0, -1))
      ONCHANGE       Recent_Count()
      ONKEY          Recent_FilesOnKey()
    END GRID

    DEFINE CHECKBOX NamesCBox
      COL      15
      WIDTH    90
      HEIGHT   16
      CAPTION  LangStr(LS_OnlyNames)
      VALUE    slRecentNames
      ONCHANGE Recent_Names()
    END CHECKBOX

    DEFINE LABEL CountLabel
      WIDTH     60
      HEIGHT    13
      ALIGNMENT RIGHT
    END LABEL

    DEFINE LABEL AmountLabel
      COL    10
      HEIGHT 13
      VALUE  LangStr(LS_FilesAmount)
    END LABEL

    DEFINE SPINNER Amount
      ROW         0
      COL         0
      WIDTH       40
      HEIGHT      21
      RANGEMIN    0
      RANGEMAX    999
      VALUE       snRecentAmount
      ONLOSTFOCUS Recent_Amount(.T.)
    END SPINNER

    DEFINE BUTTON OpenButton
      WIDTH   70
      HEIGHT  23
      CAPTION LangStr(LS_Open)
      ACTION  Recent_FileOpen(0, -1)
    END BUTTON

    DEFINE BUTTON OpenMenu
      WIDTH   20
      HEIGHT  23
      PICTURE "BmpArrowS"
      ACTION  Recent_OpenMenu()
    END BUTTON

    DEFINE BUTTON RemoveButton
      WIDTH   70
      HEIGHT  23
      CAPTION LangStr(LS_Remove)
      ACTION  Recent_FileRemove(1)
    END BUTTON

    DEFINE BUTTON RemoveMenu
      WIDTH   20
      HEIGHT  23
      PICTURE "BmpArrowS"
      ACTION  Recent_RemoveMenu()
    END BUTTON
  END WINDOW

  ON KEY F1 OF RecentWnd ACTION NIL

  ListView_ChangeExtendedStyle(RecentWnd.Files.HANDLE, LVS_EX_INFOTIP)

  FOR EACH aFile IN saRecent
    RecentWnd.Files.AddItem({If(slRecentNames, HB_fNameName(aFile[RECENTF_NAME]), aFile[RECENTF_NAME]), aFile[RECENTF_PAGE]})
  NEXT

  RecentWnd.Files.VALUE := 1

  RecentWnd.AmountLabel.WIDTH := GetWindowTextWidth(RecentWnd.AmountLabel.HANDLE, NIL, .T.)

  Recent_Count()
  Recent_ButtonsEnable()
  Recent_Resize()

  RecentWnd.CenterIn(PDFviewWnd)
  RecentWnd.ACTIVATE

  nHFrame := Sumatra_FrameHandle(PanelName())

  IF slFilesPanel .and. lFileFocus .or. (nHFrame == 0)
    PDFviewWnd.Files.SETFOCUS
  ELSE
    SetFocus(nHFrame)
  ENDIF

RETURN NIL


FUNCTION Recent_Resize()
  LOCAL nCAW := RecentWnd.CLIENTAREAWIDTH
  LOCAL nCAH := RecentWnd.CLIENTAREAHEIGHT

  RecentWnd.Files.WIDTH      := nCAW - 20
  RecentWnd.Files.HEIGHT     := nCAH - 74
  RecentWnd.NamesCBox.ROW    := nCAH - 59
  RecentWnd.CountLabel.ROW   := nCAH - 59
  RecentWnd.CountLabel.COL   := nCAW - RecentWnd.CountLabel.WIDTH - 15
  RecentWnd.AmountLabel.ROW  := nCAH - 29
  RecentWnd.Amount.ROW       := nCAH - 32
  RecentWnd.Amount.COL       := RecentWnd.AmountLabel.WIDTH + 13
  RecentWnd.OpenButton.ROW   := nCAH - 33
  RecentWnd.OpenButton.COL   := nCAW - 200
  RecentWnd.OpenMenu.ROW     := nCAH - 33
  RecentWnd.OpenMenu.COL     := nCAW - 130
  RecentWnd.RemoveButton.ROW := nCAH - 33
  RecentWnd.RemoveButton.COL := nCAW - 100
  RecentWnd.RemoveMenu.ROW   := nCAH - 33
  RecentWnd.RemoveMenu.COL   := nCAW - 30

  RecentWnd.Files.ColumnWIDTH(1) := nCAW - 20 - 4 - RecentWnd.Files.ColumnWIDTH(2) - If(RecentWnd.Files.ITEMCOUNT > ListViewGetCountPerPage(RecentWnd.Files.HANDLE), GetVScrollBarWidth(), 0)

RETURN NIL


FUNCTION Recent_FilesOnKey()

  IF ! slMenuActive
    IF (HMG_GetLastVirtualKeyDown() == VK_DELETE) .and. ((GetKeyState(VK_CONTROL) < 0) .or. (GetKeyState(VK_SHIFT) < 0)) .and. (GetKeyState(VK_MENU) >= 0)
      HMG_CleanLastVirtualKeyDown()

      IF GetKeyState(VK_SHIFT) < 0
        IF GetKeyState(VK_CONTROL) < 0
          Recent_FileRemove(3)
        ELSE
          Recent_FileRemove(1)
        ENDIF
      ELSE
        Recent_FileRemove(2)
      ENDIF
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Recent_FilesMenu(nRow, nCol)
  LOCAL aRect
  LOCAL nHMenu
  LOCAL nCmd

  IF RecentWnd.Files.ITEMCOUNT == 0
    RETURN NIL
  ENDIF

  //menu from keyboard
  IF nRow == 0xFFFF
    SendMessage(RecentWnd.Files.HANDLE, 0x1013 /*LVM_ENSUREVISIBLE*/, RecentWnd.Files.VALUE - 1, 0)
  ENDIF

  aRect    := ListView_GetItemRect(RecentWnd.Files.HANDLE, RecentWnd.Files.VALUE - 1)
  aRect[4] := ClientToScreenRow(RecentWnd.Files.HANDLE, aRect[1] + aRect[4])
  aRect[1] := ClientToScreenRow(RecentWnd.Files.HANDLE, aRect[1])
  aRect[2] := ClientToScreenCol(RecentWnd.Files.HANDLE, aRect[2])

  IF nRow == 0xFFFF
    nRow := aRect[4]
    nCol := aRect[2]
  ELSEIF (nRow < aRect[1]) .or. (nRow > aRect[4])
    RETURN NIL
  ENDIF

  nHMenu := CreatePopupMenu()

  AppendMenuString(nHMenu, 1, LangStr(LS_OpenInNewTab) + e"\tEnter")
  AppendMenuString(nHMenu, 2, LangStr(LS_OpenInCurTab) + e"\tShift+Enter")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 3, LangStr(LS_OpenPageInNewTab) + e"...\tCtrlt+Enter")
  AppendMenuString(nHMenu, 4, LangStr(LS_OpenPageInCurTab) + e"...\tCtrlt+Shift+Enter")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 5, LangStr(LS_Remove)         + e"\tShift+Del")
  AppendMenuString(nHMenu, 6, LangStr(LS_RemoveNonExist) + e"\tCtrl+Del")
  AppendMenuString(nHMenu, 7, LangStr(LS_RemoveAll)      + e"\tCtrl+Shift+Del")

  slMenuActive := .T.

  nCmd := TrackPopupMenu2(nHMenu, 0x0180 /*TPM_NONOTIFY|TPM_RETURNCMD*/, nRow, nCol, RecentWnd.HANDLE)

  DestroyMenu(nHMenu)
  slMenuActive := .F.

  SWITCH nCmd
    CASE 1
      Recent_FileOpen(0, -1)
      EXIT
    CASE 2
      Recent_FileOpen(0, 0)
      EXIT
    CASE 3
      Recent_FileOpen(-1, -1)
      EXIT
    CASE 4
      Recent_FileOpen(-1, 0)
      EXIT
    CASE 5
    CASE 6
    CASE 7
      Recent_FileRemove(nCmd - 4)
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION Recent_ButtonsEnable()
  LOCAL lEnable := (RecentWnd.Files.ITEMCOUNT > 0)
  LOCAL nHFocus := GetFocus()

  IF (! lEnable) .and. ((nHFocus == RecentWnd.OpenButton.HANDLE) .or. (nHFocus == RecentWnd.RemoveButton.HANDLE))
    RecentWnd.Files.SETFOCUS
  ENDIF

  RecentWnd.OpenButton.ENABLED   := lEnable
  RecentWnd.OpenMenu.ENABLED     := lEnable
  RecentWnd.RemoveButton.ENABLED := lEnable
  RecentWnd.RemoveMenu.ENABLED   := lEnable

RETURN NIL


FUNCTION Recent_Names()
  LOCAL n

  slRecentNames := RecentWnd.NamesCBox.VALUE

  FOR n := 1 TO Len(saRecent)
    RecentWnd.Files.CellEx(n, 1) := If(slRecentNames, HB_fNameName(saRecent[n][RECENTF_NAME]), saRecent[n][RECENTF_NAME])
  NEXT

RETURN NIL


FUNCTION Recent_Count()

  RecentWnd.CountLabel.VALUE := HB_NtoS(RecentWnd.Files.VALUE) + "/" + HB_NtoS(RecentWnd.Files.ITEMCOUNT)

RETURN NIL


FUNCTION Recent_Amount(lRefreshList)
  LOCAL n

  snRecentAmount := RecentWnd.Amount.VALUE

  IF snRecentAmount < Len(saRecent)
    IF lRefreshList
      EnableWindowRedraw(RecentWnd.Files.HANDLE, .F.)

      FOR n := Len(saRecent) TO (snRecentAmount + 1) STEP -1
        RecentWnd.Files.DeleteItem(n)
      NEXT

      IF RecentWnd.Files.VALUE == 0
        RecentWnd.Files.VALUE := snRecentAmount
      ENDIF

      EnableWindowRedraw(RecentWnd.Files.HANDLE, .T., .T.)
      Recent_Count()
      Recent_ButtonsEnable()
    ENDIF

    aSize(saRecent, snRecentAmount)
  ENDIF

RETURN NIL


FUNCTION Recent_OpenMenu()
  LOCAL aRect  := Array(4)
  LOCAL nHMenu := CreatePopupMenu()
  LOCAL nCmd

  GetWindowRect(RecentWnd.OpenMenu.HANDLE, aRect)

  AppendMenuString(nHMenu, 1, LangStr(LS_OpenInNewTab) + e"\tEnter")
  AppendMenuString(nHMenu, 2, LangStr(LS_OpenInCurTab) + e"\tShift+Enter")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 3, LangStr(LS_OpenPageInNewTab) + e"...\tCtrlt+Enter")
  AppendMenuString(nHMenu, 4, LangStr(LS_OpenPageInCurTab) + e"...\tCtrlt+Shift+Enter")

  nCmd := TrackPopupMenu2(nHMenu, 0x0188 /*TPM_NONOTIFY|TPM_RETURNCMD|TPM_RIGHTALIGN*/, aRect[4], aRect[3], RecentWnd.HANDLE)

  DestroyMenu(nHMenu)

  SWITCH nCmd
    CASE 1
      Recent_FileOpen(0, -1)
      EXIT
    CASE 2
      Recent_FileOpen(0, 0)
      EXIT
    CASE 3
      Recent_FileOpen(-1, -1)
      EXIT
    CASE 4
      Recent_FileOpen(-1, 0)
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION Recent_RemoveMenu()
  LOCAL aRect  := Array(4)
  LOCAL nHMenu := CreatePopupMenu()
  LOCAL nCmd

  GetWindowRect(RecentWnd.RemoveMenu.HANDLE, aRect)

  AppendMenuString(nHMenu, 1, LangStr(LS_Remove)         + e"\tShift+Del")
  AppendMenuString(nHMenu, 2, LangStr(LS_RemoveNonExist) + e"\tCtrl+Del")
  AppendMenuString(nHMenu, 3, LangStr(LS_RemoveAll)      + e"\tCtrl+Shift+Del")

  nCmd := TrackPopupMenu2(nHMenu, 0x0188 /*TPM_NONOTIFY|TPM_RETURNCMD|TPM_RIGHTALIGN*/, aRect[4], aRect[3], RecentWnd.HANDLE)

  DestroyMenu(nHMenu)

  IF nCmd > 0
    Recent_FileRemove(nCmd)
  ENDIF

RETURN NIL


FUNCTION Recent_FileOpen(nPage, nTab)
  LOCAL nPos := RecentWnd.Files.VALUE
  LOCAL cFile
  LOCAL n

  IF nPos > 0
    cFile := saRecent[nPos][RECENTF_NAME]

    FileOpen(cFile, nPage, nTab)

    IF slTabGoToFile
      Files_GoTo()
    ENDIF

    EnableWindowRedraw(RecentWnd.Files.HANDLE, .F.)

    IF RecentWnd.Files.ITEMCOUNT < Len(saRecent)
      RecentWnd.Files.AddItem({""})
    ENDIF

    FOR n := 1 TO Len(saRecent)
      RecentWnd.Files.Item(n) := {If(slRecentNames, HB_fNameName(saRecent[n][RECENTF_NAME]), saRecent[n][RECENTF_NAME]), saRecent[n][RECENTF_PAGE]}

      IF HMG_StrCmp(cFile, saRecent[n][RECENTF_NAME], .F.) == 0
        nPos := n
      ENDIF
    NEXT

    RecentWnd.Files.VALUE := nPos

    EnableWindowRedraw(RecentWnd.Files.HANDLE, .T., .T.)
    Recent_Count()
  ENDIF

RETURN NIL


/*
  nAction:
    1 - remove selected
    2 - remove non-existent
    3 - remove all
*/
FUNCTION Recent_FileRemove(nAction)
  LOCAL nPos := RecentWnd.Files.VALUE
  LOCAL n

  IF nPos > 0
    IF nAction == 1
      HB_aDel(saRecent, nPos, .T.)
      RecentWnd.Files.DeleteItem(nPos)

      IF nPos > RecentWnd.Files.ITEMCOUNT
        --nPos
      ENDIF

      RecentWnd.Files.VALUE := nPos
    ELSEIF nAction == 2
      EnableWindowRedraw(RecentWnd.Files.HANDLE, .F.)

      FOR n := Len(saRecent) TO 1 STEP -1
        IF ! HB_FileExists(saRecent[n][RECENTF_NAME])
          HB_aDel(saRecent, n, .T.)
          RecentWnd.Files.DeleteItem(n)
        ENDIF
      NEXT

      IF nPos > RecentWnd.Files.ITEMCOUNT
        --nPos
      ENDIF

      RecentWnd.Files.VALUE := nPos

      EnableWindowRedraw(RecentWnd.Files.HANDLE, .T., .T.)
    ELSEIF nAction == 3
      aSize(saRecent, 0)
      RecentWnd.Files.DELETEALLITEMS
    ENDIF

    Recent_Count()
    Recent_ButtonsEnable()
  ENDIF

RETURN NIL


FUNCTION PdfTranslate()
  LOCAL cText := AllTrim(Sumatra_GetSelText(PanelName()))
  LOCAL nLimit
  LOCAL aLang
  LOCAL nEventID
  LOCAL k, n

  IF Empty(cText)
    RETURN NIL
  ENDIF

  //Google Translate - limit text length is 5000 characters per translation
  nLimit := 5000
  IF HB_UTF8Len(cText) > nLimit
    cText := HB_UTF8SubStr(cText, 1, nLimit)
  ENDIF

  aLang := {{NIL, "af"   } /*LS_Afrikaans    */ , ;
            {NIL, "ar"   } /*LS_Arabic       */ , ;
            {NIL, "az"   } /*LS_Azerbaijani  */ , ;
            {NIL, "be"   } /*LS_Belarusian   */ , ;
            {NIL, "bg"   } /*LS_Bulgarian    */ , ;
            {NIL, "bs"   } /*LS_Bosnian      */ , ;
            {NIL, "ca"   } /*LS_Catalan      */ , ;
            {NIL, "cs"   } /*LS_Czech        */ , ;
            {NIL, "cy"   } /*LS_Welsh        */ , ;
            {NIL, "da"   } /*LS_Danish       */ , ;
            {NIL, "de"   } /*LS_German       */ , ;
            {NIL, "el"   } /*LS_Greek        */ , ;
            {NIL, "en"   } /*LS_English      */ , ;
            {NIL, "eo"   } /*LS_Esperanto    */ , ;
            {NIL, "es"   } /*LS_Spanish      */ , ;
            {NIL, "et"   } /*LS_Estonian     */ , ;
            {NIL, "fa"   } /*LS_Persian      */ , ;
            {NIL, "fi"   } /*LS_Finnish      */ , ;
            {NIL, "fr"   } /*LS_French       */ , ;
            {NIL, "ga"   } /*LS_Irish        */ , ;
            {NIL, "gl"   } /*LS_Galician     */ , ;
            {NIL, "hi"   } /*LS_Hindi        */ , ;
            {NIL, "hr"   } /*LS_Croatian     */ , ;
            {NIL, "ht"   } /*LS_HaitianCreole*/ , ;
            {NIL, "hu"   } /*LS_Hungarian    */ , ;
            {NIL, "hy"   } /*LS_Armenian     */ , ;
            {NIL, "id"   } /*LS_Indonesian   */ , ;
            {NIL, "is"   } /*LS_Icelandic    */ , ;
            {NIL, "it"   } /*LS_Italian      */ , ;
            {NIL, "iw"   } /*LS_Hebrew       */ , ;
            {NIL, "ja"   } /*LS_Japanese     */ , ;
            {NIL, "ka"   } /*LS_Georgian     */ , ;
            {NIL, "ko"   } /*LS_Korean       */ , ;
            {NIL, "la"   } /*LS_Latin        */ , ;
            {NIL, "lt"   } /*LS_Lithuanian   */ , ;
            {NIL, "lv"   } /*LS_Latvian      */ , ;
            {NIL, "mk"   } /*LS_Macedonian   */ , ;
            {NIL, "ms"   } /*LS_Malay        */ , ;
            {NIL, "mt"   } /*LS_Maltese      */ , ;
            {NIL, "nl"   } /*LS_Dutch        */ , ;
            {NIL, "no"   } /*LS_Norwegian    */ , ;
            {NIL, "pa"   } /*LS_Punjabi      */ , ;
            {NIL, "pl"   } /*LS_Polish       */ , ;
            {NIL, "pt"   } /*LS_Portuguese   */ , ;
            {NIL, "ro"   } /*LS_Romanian     */ , ;
            {NIL, "ru"   } /*LS_Russian      */ , ;
            {NIL, "sk"   } /*LS_Slovak       */ , ;
            {NIL, "sl"   } /*LS_Slovenian    */ , ;
            {NIL, "sq"   } /*LS_Albanian     */ , ;
            {NIL, "sr"   } /*LS_Serbian      */ , ;
            {NIL, "sv"   } /*LS_Swedish      */ , ;
            {NIL, "sw"   } /*LS_Swahili      */ , ;
            {NIL, "ta"   } /*LS_Tamil        */ , ;
            {NIL, "th"   } /*LS_Thai         */ , ;
            {NIL, "tl"   } /*LS_Filipino     */ , ;
            {NIL, "tr"   } /*LS_Turkish      */ , ;
            {NIL, "uk"   } /*LS_Ukrainian    */ , ;
            {NIL, "ur"   } /*LS_Urdu         */ , ;
            {NIL, "vi"   } /*LS_Vietnamese   */ , ;
            {NIL, "yi"   } /*LS_Yiddish      */ , ;
            {NIL, "zh-CN"} /*LS_ChineseSimp  */ , ;
            {NIL, "zh-TW"} /*LS_ChineseTrad  */ }

  k := LS_Afrikaans

  FOR n := 1 TO Len(aLang)
    aLang[n][1] := LangStr(k++)
  NEXT

  aSort(aLang, NIL, NIL, {|a1, a2| (HMG_StrCmp(a1[1], a2[1], .F.) < 0)})

  DEFINE WINDOW TranslateWnd;
    ROW    (PDFviewWnd.ROW) + (PDFviewWnd.HEIGHT) - snTranslate_H;
    COL    PDFviewWnd.COL;
    WIDTH  snTranslate_W;
    HEIGHT snTranslate_H;
    TITLE  LangStr(LS_GoogleTranslator);
    MODAL;
    ON INIT    Translate_Google(cText, aLang);
    ON PAINT   PaintSizeGrip(TranslateWnd.HANDLE);
    ON SIZE    Translate_Resize();
    ON RELEASE ((snTranslate_W := TranslateWnd.WIDTH), ;
                (snTranslate_H := TranslateWnd.HEIGHT), ;
                (scTranslateLang1 := If(TranslateWnd.Lang1Combo.VALUE > 1, aLang[TranslateWnd.Lang1Combo.VALUE - 1][2], "")), ;
                (scTranslateLang2 := aLang[TranslateWnd.Lang2Combo.VALUE][2]))

    DEFINE COMBOBOX Lang1Combo
      ROW     10
      COL     10
      WIDTH   160
      HEIGHT  250
    END COMBOBOX

    DEFINE LABEL LangLabel
      ROW    13
      COL    174
      WIDTH  12
      HEIGHT 13
      VALUE  "=>"
    END LABEL

    DEFINE COMBOBOX Lang2Combo
      ROW     10
      COL     190
      WIDTH   160
      HEIGHT  250
    END COMBOBOX

    DEFINE BUTTON TranslateButton
      ROW     10
      COL     360
      WIDTH   80
      HEIGHT  23
      CAPTION LangStr(LS_Translate)
      ACTION  Translate_Google(cText, aLang)
    END BUTTON

    DEFINE EDITBOX TranslationEBox
      ROW      48
      COL      10
      READONLY .T.
    END EDITBOX

    DEFINE LABEL StatusLabel
      ROW    33
      COL    15
      WIDTH  200
      HEIGHT 13
    END LABEL

  END WINDOW

  TranslateWnd.Lang1Combo.AddItem("<" + LangStr(LS_AutoDetection) + ">")

  FOR n := 1 TO Len(aLang)
    TranslateWnd.Lang1Combo.AddItem(aLang[n][1])
    TranslateWnd.Lang2Combo.AddItem(aLang[n][1])
  NEXT

  TranslateWnd.Lang1Combo.VALUE := HB_aScan(aLang, {|a| a[2] == scTranslateLang1}) + 1

  IF (n := HB_aScan(aLang, {|a| a[2] == scTranslateLang2})) == 0
    TranslateWnd.Lang2Combo.VALUE := 1
  ELSE
    TranslateWnd.Lang2Combo.VALUE := n
  ENDIF

  nEventID := EventCreate({|| If(EventWPARAM() == VK_ESCAPE, (TranslateWnd.TranslateButton.SETFOCUS, TranslateWnd.RELEASE), NIL)}, TranslateWnd.TranslationEBox.HANDLE, WM_KEYDOWN)

  ON KEY F1 OF TranslateWnd ACTION NIL

  Translate_Resize()
  TranslateWnd.ACTIVATE

  EventRemove(nEventID)
RETURN NIL


FUNCTION Translate_Resize()

  TranslateWnd.TranslationEBox.WIDTH  := TranslateWnd.CLIENTAREAWIDTH - 20
  TranslateWnd.TranslationEBox.HEIGHT := TranslateWnd.CLIENTAREAHEIGHT - 58

RETURN NIL


/*
  https://msdn.microsoft.com/en-us/library/ms537505(v=vs.85).aspx
  https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest
*/
FUNCTION Translate_Google(cText, aLang)
  LOCAL cURL    := "https://translate.google.com/translate_a/single"
  LOCAL cTarget := ""
  LOCAL cLang1
  LOCAL cLang2
  LOCAL cData
  LOCAL bErrHandler
  LOCAL oRequest
  LOCAL aResponse
  LOCAL i, k, n

  TranslateWnd.StatusLabel.FONTCOLOR := RED
  TranslateWnd.StatusLabel.VALUE     := LangStr(LS_Wait) + "..."
  TranslateWnd.TranslationEBox.VALUE := cTarget
  TranslateWnd.TranslationEBox.REDRAW

  IF TranslateWnd.Lang1Combo.VALUE == 1
    cLang1 := "auto"
  ELSE
    cLang1 := aLang[TranslateWnd.Lang1Combo.VALUE - 1][2]
  ENDIF

  cLang2      := aLang[TranslateWnd.Lang2Combo.VALUE][2]
  cData       := "client=qlt&dt=bd&dt=t&sl=" + cLang1 + "&tl=" + cLang2 + "&q=" + EncodeURIComponent(cText)
  bErrHandler := ErrorBlock({|| Break(NIL)})

  BEGIN SEQUENCE
    oRequest := CreateObject("Microsoft.XMLHTTP")

    oRequest:open("POST", cURL, .F. /*async==.F.*/)
    oRequest:setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    oRequest:send(cData)

    IF oRequest:status != 200
      Break(NIL)
    ENDIF

    IF HB_jsonDecode(oRequest:responseText, @aResponse) > 0
      cLang1 := aResponse[3]

      FOR i := 1 TO Len(aResponse[1])
        cTarget += aResponse[1][i][1]
      NEXT

      //dictionary and reverse translation
      IF ! Empty(aResponse[2])
        FOR i := 1 TO Len(aResponse[2])
          cTarget += CRLF2 + aResponse[2][i][1] + ":"

          FOR k := 1 TO Len(aResponse[2][i][3])
            cTarget += CRLF + HB_NtoS(k) + ". " + aResponse[2][i][3][k][1]

            IF ! Empty(aResponse[2][i][3][k][2])
              cTarget += " ("

              FOR n := 1 TO Len(aResponse[2][i][3][k][2])
                cTarget += aResponse[2][i][3][k][2][n] + If(n < Len(aResponse[2][i][3][k][2]), ", ", ")")
              NEXT //n
            ENDIF
          NEXT //k
        NEXT //i
      ENDIF
    ENDIF

  RECOVER
    cTarget := ""
  END SEQUENCE

  ErrorBlock(bErrHandler)

  IF Empty(cTarget)
    TranslateWnd.StatusLabel.VALUE := LangStr(LS_TranslateError)
  ELSE
    TranslateWnd.StatusLabel.FONTCOLOR := BLACK

    IF TranslateWnd.Lang1Combo.VALUE == 1
      n := HB_aScan(aLang, {|a| a[2] == cLang1})

      TranslateWnd.StatusLabel.VALUE := If(n == 0, cLang1, aLang[n][1])
    ELSE
      TranslateWnd.StatusLabel.VALUE := ""
    ENDIF

    TranslateWnd.TranslationEBox.VALUE := cTarget
  ENDIF

RETURN NIL


FUNCTION PdfMerge(nRowMenu, nColMenu)
  STATIC aFile       := {}
  STATIC nTotalPages := 0
  LOCAL  cFileName
  LOCAL  nPages
  LOCAL  nRow
  LOCAL  nCol
  LOCAL  nHFocus
  LOCAL  n

  IF HB_IsNumeric(nRowMenu) .and. HB_IsNumeric(nColMenu)
    PdfMerge_FilesMenu(@aFile, @nTotalPages, nRowMenu, nColMenu)
    RETURN NIL
  ENDIF

  IF IsWindowActive(MergeWnd)
    IF IsWindowActive(SplitWnd)
      SplitWnd.MINIMIZE
    ENDIF

    IF IsWindowActive(BooksWnd)
      BooksWnd.MINIMIZE
    ENDIF

    MergeWnd.RESTORE
    RETURN NIL
  ENDIF

  nRow := GetProperty(PanelName(), "ROW")
  nCol := GetProperty(PanelName(), "COL")
  ClientToScreen(PDFviewWnd.HANDLE, @nCol, @nRow)

  DEFINE WINDOW MergeWnd;
    ROW    nRow;
    COL    nCol;
    WIDTH  snMerge_W;
    HEIGHT snMerge_H;
    TITLE  LangStr(LS_MergeSplitRotate, .T.);
    CHILD;
    NOMAXIMIZE;
    ON GOTFOCUS SetFocus(nHFocus);
    ON PAINT    PaintSizeGrip(MergeWnd.HANDLE);
    ON SIZE     PdfMerge_Resize();
    ON RELEASE  (aSize(aFile, 0), (nTotalPages := 0), (snMerge_W := MergeWnd.WIDTH), (snMerge_H := MergeWnd.HEIGHT))

    DEFINE GRID Files
      ROW            10
      COL            10
      HEADERS        {LangStr(LS_Documents)}
      WIDTHS         {0}
      CELLNAVIGATION .F.
      ONCHANGE       (PdfMerge_ButtonsEnable(), ;
                      (MergeWnd.FileNumLabel.VALUE := HB_NtoS(MergeWnd.Files.VALUE) + "/" + HB_NtoS(Len(aFile))), ;
                      (MergeWnd.RangesTBox.VALUE := If(This.Value > 0, aFile[This.Value][MERGEF_RANGEIN], "")), ;
                      MergeWnd.RangesTBox.REDRAW, ;
                      PdfMerge_ShowPages(@aFile, This.Value))
      ONDBLCLICK     If(This.Value > 0, MergeWnd.RangesTBox.SETFOCUS, NIL)
      ONKEY          PdfMerge_FilesOnKey(@aFile, @nTotalPages)
      ONGOTFOCUS     (nHFocus := This.HANDLE)
    END GRID

    DEFINE CHECKBOX NamesCBox
      COL        15
      WIDTH      90
      HEIGHT     16
      CAPTION    LangStr(LS_OnlyNames)
      VALUE      slMergeNames
      ONCHANGE   PdfMerge_Names(@aFile)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END CHECKBOX

    DEFINE LABEL FileNumLabel
      WIDTH     100
      HEIGHT    13
      VALUE     ""
      ALIGNMENT RIGHT
    END LABEL

    DEFINE BUTTON AddButton
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Add)
      ACTION     PdfMerge_Add(@aFile, @nTotalPages, (GetKeyState(VK_SHIFT) < 0))
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON

    DEFINE BUTTON DupButton
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Duplicate)
      ACTION     PdfMerge_Duplicate(@aFile, @nTotalPages)
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON

    DEFINE BUTTON RemoveButton
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Remove)
      ACTION     PdfMerge_Remove(@aFile, @nTotalPages)
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON

    DEFINE BUTTON UpButton
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Up)
      ACTION     PdfMerge_UpDown(@aFile, @nTotalPages, .F.)
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON

    DEFINE BUTTON DownButton
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Down)
      ACTION     PdfMerge_UpDown(@aFile, @nTotalPages, .T.)
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON

    DEFINE LABEL RangesLabel
      COL    10
      WIDTH  200
      HEIGHT 13
      VALUE  LangStr(LS_PageRanges) + ":"
    END LABEL

    DEFINE LABEL PagesLabel
      WIDTH     100
      HEIGHT    13
      VALUE     ""
      ALIGNMENT RIGHT
    END LABEL

    DEFINE TEXTBOX RangesTBox
      COL               10
      HEIGHT            21
      DATATYPE          CHARACTER
      DISABLEDBACKCOLOR ColorArray(GetSysColor(15 /*COLOR_BTNFACE*/))
      ONCHANGE          PdfMerge_GetPages(@aFile, @nTotalPages)
      ONENTER           MergeWnd.Files.SETFOCUS
      ONGOTFOCUS        (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE BUTTON RangesButton
      WIDTH      20
      HEIGHT     23
      CAPTION    "?"
      ACTION     PDFtk_PageRangesHelp(.T., MergeWnd.RangesTBox.HANDLE)
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON

    DEFINE FRAME PassFrame
      COL     10
      HEIGHT  61
      CAPTION LangStr(LS_PassProtect)
    END FRAME

    DEFINE LABEL OwnPassLabel
      COL    20
      WIDTH  150
      HEIGHT 13
      VALUE  LangStr(LS_OwnerPass)
    END LABEL

    DEFINE TEXTBOX OwnPassTBox
      COL        20
      HEIGHT     21
      MAXLENGTH  32
      DATATYPE   CHARACTER
      PASSWORD   (! slPassShow)
      ONCHANGE   PdfMerge_ShowPages(@aFile, MergeWnd.Files.VALUE, @nTotalPages)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE LABEL UserPassLabel
      WIDTH  150
      HEIGHT 13
      VALUE  LangStr(LS_UserPass)
    END LABEL

    DEFINE TEXTBOX UserPassTBox
      HEIGHT     21
      MAXLENGTH  32
      DATATYPE   CHARACTER
      PASSWORD   (! slPassShow)
      ONCHANGE   PdfMerge_ShowPages(@aFile, MergeWnd.Files.VALUE, @nTotalPages)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE CHECKBOX PassShowCBox
      WIDTH      110
      HEIGHT     16
      VALUE      slPassShow
      CAPTION    LangStr(LS_ShowPass)
      ONCHANGE   ((slPassShow := MergeWnd.PassShowCBox.VALUE), ;
                   SendMessage(MergeWnd.OwnPassTBox.HANDLE,  0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), MergeWnd.OwnPassTBox.REDRAW, ;
                   SendMessage(MergeWnd.UserPassTBox.HANDLE, 0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), MergeWnd.UserPassTBox.REDRAW)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END CHECKBOX

    DEFINE LABEL StatusLabel
      COL    10
      WIDTH  260
      HEIGHT 13
      VALUE  ""
    END LABEL

    DEFINE BUTTON MakeButton
      WIDTH       80
      HEIGHT      23
      CAPTION     LangStr(LS_Make)
      ACTION      PDFtk_Merge(@aFile, @nTotalPages)
      ONGOTFOCUS  ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
      ONLOSTFOCUS SetDefPushButton(This.HANDLE, .F.)
    END BUTTON

    DEFINE BUTTON CloseButton
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Close)
      ACTION     MergeWnd.RELEASE
      ONGOTFOCUS ((nHFocus := This.HANDLE), SetDefPushButton(nHFocus, .T.))
    END BUTTON
  END WINDOW

  FOR n := 1 TO Len(saTab)
    nPages := Sumatra_PageCount(PanelName(saTab[n]))
    IF nPages > 0
      cFileName := Sumatra_FileName(PanelName(saTab[n]))
      aAdd(aFile, {cFileName, nPages, nPages, "", "", "", FileRecentGetPass(cFileName)})
    ENDIF
  NEXT

  IF ! Empty(aFile)
    FOR n := 1 TO Len(aFile)
      MergeWnd.Files.AddItem({If(slMergeNames, HB_fNameName(aFile[n][MERGEF_NAME]), aFile[n][MERGEF_NAME])})
      nTotalPages += aFile[n][MERGEF_PAGESOUT]
    NEXT

    MergeWnd.Files.VALUE := 1
    PdfMerge_ShowPages(@aFile, 1, @nTotalPages)
  ENDIF

  MergeWnd.Files.SETFOCUS
  MergeWnd.Files.PAINTDOUBLEBUFFER := .T.
  ListView_ChangeExtendedStyle(MergeWnd.Files.HANDLE, LVS_EX_INFOTIP)
  HMG_ChangeWindowStyle(MergeWnd.PassFrame.HANDLE, 0x0300 /*BS_CENTER*/, NIL, NIL, .T.)
  PdfMerge_ButtonsEnable()
  PdfMerge_Resize()

  ON KEY F1              OF MergeWnd ACTION If(GetFocus() == MergeWnd.RangesTBox.HANDLE, PDFtk_PageRangesHelp(.T., MergeWnd.RangesTBox.HANDLE), NIL)
  ON KEY F6              OF MergeWnd ACTION ModelessSetFocus(ThisWindow.NAME)
  ON KEY CONTROL+SHIFT+B OF MergeWnd ACTION If(IsWindowActive(BooksWnd), (MergeWnd.MINIMIZE, BooksWnd.RESTORE), NIL)
  ON KEY CONTROL+SHIFT+M OF MergeWnd ACTION MergeWnd.MINIMIZE
  ON KEY CONTROL+SHIFT+S OF MergeWnd ACTION If(IsWindowActive(SplitWnd), (MergeWnd.MINIMIZE, SplitWnd.RESTORE), NIL)

  MergeWnd.ACTIVATE

RETURN NIL


FUNCTION PdfMerge_Resize()
  LOCAL nCAW := MergeWnd.CLIENTAREAWIDTH
  LOCAL nCAH := MergeWnd.CLIENTAREAHEIGHT

  MergeWnd.Files.WIDTH        := nCAW - 20
  MergeWnd.Files.HEIGHT       := nCAH - 224
  MergeWnd.NamesCBox.ROW      := nCAH - 209
  MergeWnd.FileNumLabel.ROW   := nCAH - 212
  MergeWnd.FileNumLabel.COL   := nCAW - 115
  MergeWnd.AddButton.ROW      := nCAH - 183
  MergeWnd.AddButton.COL      := Round((nCAW - 440) / 2, 0)
  MergeWnd.DupButton.ROW      := nCAH - 183
  MergeWnd.DupButton.COL      := MergeWnd.AddButton.COL + 90
  MergeWnd.RemoveButton.ROW   := nCAH - 183
  MergeWnd.RemoveButton.COL   := MergeWnd.DupButton.COL + 90
  MergeWnd.UpButton.ROW       := nCAH - 183
  MergeWnd.UpButton.COL       := MergeWnd.RemoveButton.COL + 90
  MergeWnd.DownButton.ROW     := nCAH - 183
  MergeWnd.DownButton.COL     := MergeWnd.UpButton.COL + 90
  MergeWnd.RangesLabel.ROW    := nCAH - 150
  MergeWnd.PagesLabel.ROW     := nCAH - 150
  MergeWnd.PagesLabel.COL     := nCAW - 130
  MergeWnd.RangesTBox.ROW     := nCAH - 135
  MergeWnd.RangesTBox.WIDTH   := nCAW - 40
  MergeWnd.RangesButton.ROW   := nCAH - 136
  MergeWnd.RangesButton.COL   := nCAW - 30
  MergeWnd.PassFrame.ROW      := nCAH - 104
  MergeWnd.PassFrame.WIDTH    := nCAW - 20
  MergeWnd.OwnPassLabel.ROW   := nCAH - 89
  MergeWnd.OwnPassTBox.ROW    := nCAH - 74
  MergeWnd.OwnPassTBox.WIDTH  := Round((nCAW - 170) / 2, 0)
  MergeWnd.UserPassLabel.ROW  := nCAH - 89
  MergeWnd.UserPassLabel.COL  := MergeWnd.OwnPassTBox.WIDTH + 30
  MergeWnd.UserPassTBox.ROW   := nCAH - 74
  MergeWnd.UserPassTBox.COL   := MergeWnd.UserPassLabel.COL
  MergeWnd.UserPassTBox.WIDTH := MergeWnd.OwnPassTBox.WIDTH
  MergeWnd.PassShowCBox.ROW   := nCAH - 69
  MergeWnd.PassShowCBox.COL   := nCAW - 130
  MergeWnd.StatusLabel.ROW    := nCAH - 23
  MergeWnd.MakeButton.ROW     := nCAH - 33
  MergeWnd.MakeButton.COL     := nCAW - 180
  MergeWnd.CloseButton.ROW    := nCAH - 33
  MergeWnd.CloseButton.COL    := nCAW - 90

  MergeWnd.Files.ColumnWIDTH(1) := nCAW - 20 - 4 - If(MergeWnd.Files.ITEMCOUNT > ListViewGetCountPerPage(MergeWnd.Files.HANDLE), GetVScrollBarWidth(), 0)

RETURN NIL


FUNCTION PdfMerge_FilesOnKey(/*@*/ aFile, /*@*/ nTotalPages)

  IF ! slMenuActive
    SWITCH HMG_GetLastVirtualKeyDown()
      CASE VK_INSERT
        HMG_CleanLastVirtualKeyDown()
        IF GetKeyState(VK_MENU) >= 0
          IF GetKeyState(VK_CONTROL) >= 0
            PdfMerge_Add(@aFile, @nTotalPages, (GetKeyState(VK_SHIFT) < 0))
          ELSEIF GetKeyState(VK_SHIFT) < 0
            PdfMerge_Duplicate(@aFile, @nTotalPages)
          ENDIF
        ENDIF
        EXIT
      CASE VK_DELETE
        HMG_CleanLastVirtualKeyDown()
        IF (GetKeyState(VK_SHIFT) < 0) .and. (GetKeyState(VK_MENU) >= 0)
          PdfMerge_Remove(@aFile, @nTotalPages, (GetKeyState(VK_CONTROL) < 0))
        ENDIF
        EXIT
      CASE VK_UP
        HMG_CleanLastVirtualKeyDown()
        IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) < 0)
          PdfMerge_UpDown(@aFile, @nTotalPages, .F.)
        ENDIF
        EXIT
      CASE VK_DOWN
        HMG_CleanLastVirtualKeyDown()
        IF (GetKeyState(VK_CONTROL) >= 0) .and. (GetKeyState(VK_SHIFT) >= 0) .and. (GetKeyState(VK_MENU) < 0)
          PdfMerge_UpDown(@aFile, @nTotalPages, .T.)
        ENDIF
        EXIT
    ENDSWITCH
  ENDIF

RETURN NIL


FUNCTION PdfMerge_ButtonsEnable()
  LOCAL nPos    := MergeWnd.Files.VALUE
  LOCAL nCount  := MergeWnd.Files.ITEMCOUNT
  LOCAL nHFocus := GetFocus()

  MergeWnd.DupButton.ENABLED    := (nCount > 0)
  MergeWnd.RemoveButton.ENABLED := (nCount > 0)
  MergeWnd.UpButton.ENABLED     := (nPos > 1)
  MergeWnd.DownButton.ENABLED   := (nPos < nCount)
  MergeWnd.RangesTBox.ENABLED   := (nCount > 0)
  MergeWnd.RangesButton.ENABLED := (nCount > 0)
  MergeWnd.MakeButton.ENABLED   := (nCount > 0)

  IF nHFocus == MergeWnd.RemoveButton.HANDLE
    IF nCount == 0
      MergeWnd.AddButton.SETFOCUS
    ENDIF
  ELSEIF (nHFocus == MergeWnd.UpButton.HANDLE)
    IF nPos == 1
      MergeWnd.DownButton.SETFOCUS
    ENDIF
  ELSEIF (nHFocus == MergeWnd.DownButton.HANDLE)
    IF nPos == nCount
      MergeWnd.UpButton.SETFOCUS
    ENDIF
  ENDIF

RETURN NIL


FUNCTION PdfMerge_Names(/*@*/ aFile)
  LOCAL n

  slMergeNames := MergeWnd.NamesCBox.VALUE

  FOR n := 1 TO Len(aFile)
    MergeWnd.Files.CellEx(n, 1) := If(slMergeNames, HB_fNameName(aFile[n][MERGEF_NAME]), aFile[n][MERGEF_NAME])
  NEXT

RETURN NIL


FUNCTION PdfMerge_FilesMenu(/*@*/ aFile, /*@*/ nTotalPages, nRow, nCol)
  LOCAL nCount := Len(aFile)
  LOCAL nHGrid := MergeWnd.Files.HANDLE
  LOCAL nPos   := MergeWnd.Files.VALUE
  LOCAL aRect
  LOCAL nHMenu
  LOCAL nCmd

  //menu from keyboard
  IF nRow == 0xFFFF
    IF nCount == 0
      nRow := ClientToScreenRow(nHGrid, GetWindowHeight(ListView_GetHeader(nHGrid)) + 3)
      nCol := ClientToScreenCol(nHGrid, 3)
    ELSE
      SendMessage(nHGrid, 0x1013 /*LVM_ENSUREVISIBLE*/, nPos - 1, 0)

      aRect := ListView_GetItemRect(nHGrid, nPos - 1)
      nRow  := ClientToScreenRow(nHGrid, aRect[1] + aRect[4])
      nCol  := ClientToScreenCol(nHGrid, aRect[2])
    ENDIF
  //rclick on header
  ELSEIF nRow < ClientToScreenRow(nHGrid, GetWindowHeight(ListView_GetHeader(nHGrid)))
    RETURN NIL
  ENDIF

  nHMenu := CreatePopupMenu()

  AppendMenuString(nHMenu, 1, LangStr(LS_Add)        + e"\tIns")
  AppendMenuString(nHMenu, 2, LangStr(LS_AddAbove)   + e"\tShift+Ins")
  AppendMenuString(nHMenu, 3, LangStr(LS_Duplicate)  + e"\tCtrl+Shift+Ins")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 4, LangStr(LS_Remove)     + e"\tShift+Del")
  AppendMenuString(nHMenu, 5, LangStr(LS_RemoveAll)  + e"\tCtrl+Shift+Del")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 6, LangStr(LS_Up)         + e"\tAlt+Up")
  AppendMenuString(nHMenu, 7, LangStr(LS_Down)       + e"\tAlt+Down")
  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, 8, LangStr(LS_EditRanges) + e"\tEnter")

  IF nCount == 0
    xDisableMenuItem(nHMenu, 2)
    xDisableMenuItem(nHMenu, 3)
    xDisableMenuItem(nHMenu, 4)
    xDisableMenuItem(nHMenu, 5)
    xDisableMenuItem(nHMenu, 8)
  ENDIF

  IF nPos < 2
    xDisableMenuItem(nHMenu, 6)
  ENDIF

  IF nPos == nCount
    xDisableMenuItem(nHMenu, 7)
  ENDIF

  slMenuActive := .T.

  nCmd := TrackPopupMenu2(nHMenu, 0x0180 /*TPM_NONOTIFY|TPM_RETURNCMD*/, nRow, nCol, MergeWnd.HANDLE)

  DestroyMenu(nHMenu)
  slMenuActive := .F.

  SWITCH nCmd
    CASE 1
      PdfMerge_Add(@aFile, @nTotalPages)
      EXIT
    CASE 2
      PdfMerge_Add(@aFile, @nTotalPages, .T.)
      EXIT
    CASE 3
      PdfMerge_Duplicate(@aFile, @nTotalPages)
      EXIT
    CASE 4
      PdfMerge_Remove(@aFile, @nTotalPages)
      EXIT
    CASE 5
      PdfMerge_Remove(@aFile, @nTotalPages, .T.)
      EXIT
    CASE 6
      PdfMerge_UpDown(@aFile, @nTotalPages, .F.)
      EXIT
    CASE 7
      PdfMerge_UpDown(@aFile, @nTotalPages, .T.)
      EXIT
    CASE 8
      HMG_PressKey(VK_RETURN)
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION PdfMerge_Add(/*@*/ aFile, /*@*/ nTotalPages, lAbove)
  LOCAL nOpened  := 0
  LOCAL nTab
  LOCAL nHMenu
  LOCAL nHButton

  HB_Default(@lAbove, .F.)

  FOR nTab := 1 TO Len(saTab)
    IF Sumatra_PageCount(PanelName(saTab[nTab])) > 0
      ++nOpened
    ENDIF
  NEXT

  IF nOpened == 0
    PdfMerge_AddFromDisk(@aFile, @nTotalPages, lAbove)
    RETURN NIL
  ENDIF

  nHMenu   := CreatePopupMenu()
  nHButton := MergeWnd.AddButton.HANDLE

  FOR nTab := 1 TO Len(saTab)
    IF Sumatra_PageCount(PanelName(saTab[nTab])) > 0
      AppendMenuString(nHMenu, nTab, Sumatra_FileName(PanelName(saTab[nTab])))
    ENDIF
  NEXT

  IF nOpened > 1
    AppendMenuSeparator(nHMenu)
    AppendMenuString(nHMenu, -1, LangStr(LS_AllOpenedDocs))
  ENDIF

  AppendMenuSeparator(nHMenu)
  AppendMenuString(nHMenu, -2, LangStr(LS_OtherDocs))

  nTab := TrackPopupMenu2(nHMenu, 0x0180 /*TPM_NONOTIFY|TPM_RETURNCMD*/, GetWindowRow(nHButton) + GetWindowHeight(nHButton), GetWindowCol(nHButton), MergeWnd.HANDLE)

  DestroyMenu(nHMenu)

  IF nTab != 0
    IF nTab == -2
      PdfMerge_AddFromDisk(@aFile, @nTotalPages, lAbove)
    ELSE
      PdfMerge_AddFromTab(@aFile, @nTotalPages, nTab, lAbove)
    ENDIF
  ENDIF

RETURN NIL


FUNCTION PdfMerge_AddFromTab(/*@*/ aFile, /*@*/ nTotalPages, nTab, lAbove)
  LOCAL nPos := MergeWnd.Files.VALUE
  LOCAL nTab1, nTab2
  LOCAL cFileName
  LOCAL nPages

  IF lAbove .and. (nPos > 0)
    --nPos
  ENDIF

  IF nTab > 0
    nTab1 := nTab
    nTab2 := nTab
  ELSE
    nTab1 := 1
    nTab2 := Len(saTab)
  ENDIF

  FOR nTab := nTab1 TO nTab2
    IF (nPages := Sumatra_PageCount(PanelName(saTab[nTab]))) > 0
      cFileName   := Sumatra_FileName(PanelName(saTab[nTab]))
      nTotalPages += nPages

      HB_aIns(aFile, ++nPos, {cFileName, nPages, nPages, "", "", "", FileRecentGetPass(cFileName)}, .T.)
      MergeWnd.Files.AddItemEx({If(slMergeNames, HB_fNameName(cFileName), cFileName)}, nPos)
    ENDIF
  NEXT

  MergeWnd.Files.VALUE := nPos
  PdfMerge_ButtonsEnable()
  PdfMerge_Resize()
  PdfMerge_ShowPages(@aFile, nPos, @nTotalPages)

RETURN NIL


FUNCTION PdfMerge_AddFromDisk(/*@*/ aFile, /*@*/ nTotalPages, lAbove)
  LOCAL nPos := MergeWnd.Files.VALUE
  LOCAL cDir
  LOCAL aFileNew
  LOCAL nPages
  LOCAL cPass
  LOCAL n, k

  IF nPos > 0
    cDir := HB_fNameDir(aFile[nPos][MERGEF_NAME])
  ELSEIF Sumatra_PageCount(PanelName()) > 0
    cDir := HB_fNameDir(Sumatra_FileName(PanelName()))
  ELSE
    cDir := scFileDir
  ENDIF

  aFileNew := GetFile({{"*.pdf", "*.pdf"}}, NIL, cDir, .T., .T.)

  IF ! (Empty(aFileNew))
    IF Empty(PDFtk_ExeName())
      RETURN NIL
    ENDIF

    MergeWnd.StatusLabel.FONTCOLOR := RED
    MergeWnd.StatusLabel.VALUE     := LangStr(LS_Wait) + "..."

    FOR n := 1 TO Len(aFileNew)
      nPages := 0
      cPass  := ""

      FOR k := 1 TO Len(aFile)
        IF HMG_StrCmp(aFileNew[n], aFile[k][MERGEF_NAME], .F.) == 0
          nPages := aFile[k][MERGEF_PAGESIN]
          cPass  := aFile[k][MERGEF_PASS]
        ENDIF
      NEXT //k

      IF nPages == 0
        cPass := FileRecentGetPass(aFileNew[n])

        FOR k := 1 TO Len(saTab)
          IF HMG_StrCmp(aFileNew[n], Sumatra_FileName(PanelName(saTab[k])), .F.) == 0
            nPages := Sumatra_PageCount(PanelName(saTab[k]))
            EXIT
          ENDIF
        NEXT //k
      ENDIF

      IF nPages == 0
        MergeWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking)
        nPages := PDFtk_PageCount(aFileNew[n], @cPass)
      ENDIF

      IF nPages == 0
        aSize(aFileNew, 0)
        EXIT
      ELSE
        aFileNew[n] := {aFileNew[n], nPages, cPass}
      ENDIF
    NEXT //n

    IF ! (Empty(aFileNew))
      IF lAbove .and. (nPos > 0)
        --nPos
      ENDIF

      FOR n := 1 TO Len(aFileNew)
        nTotalPages += aFileNew[n][2]

        HB_aIns(aFile, ++nPos, {aFileNew[n][1], aFileNew[n][2], aFileNew[n][2], "", "", "", aFileNew[n][3]}, .T.)
        MergeWnd.Files.AddItemEx({If(slMergeNames, HB_fNameName(aFileNew[n][1]), aFileNew[n][1])}, nPos)
      NEXT

      MergeWnd.Files.VALUE := nPos
      PdfMerge_ButtonsEnable()
      PdfMerge_Resize()
    ENDIF

    PdfMerge_ShowPages(@aFile, nPos, @nTotalPages)
  ENDIF

RETURN NIL


FUNCTION PdfMerge_Duplicate(/*@*/ aFile, /*@*/ nTotalPages)
  LOCAL nPos := MergeWnd.Files.VALUE

  IF nPos > 0
    nTotalPages += aFile[nPos][MERGEF_PAGESOUT]

    HB_aIns(aFile, nPos + 1, aClone(aFile[nPos]), .T.)
    MergeWnd.Files.AddItemEx(MergeWnd.Files.Item(nPos), nPos + 1)

    MergeWnd.Files.VALUE := ++nPos
    PdfMerge_ButtonsEnable()
    PdfMerge_Resize()
    PdfMerge_ShowPages(@aFile, nPos, @nTotalPages)
  ENDIF

RETURN NIL


FUNCTION PdfMerge_Remove(/*@*/ aFile, /*@*/ nTotalPages, lAll)
  LOCAL nPos := MergeWnd.Files.VALUE

  IF nPos > 0
    HB_Default(@lAll, .F.)

    IF lAll
      nTotalPages := 0
      nPos        := 0

      aSize(aFile, 0)
      MergeWnd.Files.DELETEALLITEMS
    ELSE
      nTotalPages -= aFile[nPos][MERGEF_PAGESOUT]

      HB_aDel(aFile, nPos, .T.)
      MergeWnd.Files.DeleteItem(nPos)

      IF nPos > MergeWnd.Files.ITEMCOUNT
        --nPos
      ENDIF
    ENDIF

    MergeWnd.Files.VALUE        := nPos
    MergeWnd.FileNumLabel.VALUE := HB_NtoS(nPos) + "/" + HB_NtoS(Len(aFile))
    MergeWnd.RangesTBox.VALUE   := If(nPos == 0, "", aFile[nPos][MERGEF_RANGEIN])

    PdfMerge_ButtonsEnable()
    PdfMerge_Resize()
    PdfMerge_ShowPages(@aFile, nPos, @nTotalPages)
  ENDIF

RETURN NIL


FUNCTION PdfMerge_UpDown(/*@*/ aFile, /*@*/ nTotalPages, lDown)
  LOCAL nPos1 := MergeWnd.Files.VALUE
  LOCAL nPos2
  LOCAL cFile
  LOCAL nInPages
  LOCAL nOutPages
  LOCAL cInRange
  LOCAL cOutRange
  LOCAL cPass

  IF lDown
    IF (nPos1 > 0) .and. (nPos1 < Len(aFile))
      nPos2 := nPos1 + 1
    ELSE
      RETURN NIL
    ENDIF
  ELSE
    IF nPos1 > 1
      nPos2 := nPos1 - 1
    ELSE
      RETURN NIL
    ENDIF
  ENDIF

  cFile     := aFile[nPos1][MERGEF_NAME]
  nInPages  := aFile[nPos1][MERGEF_PAGESIN]
  nOutPages := aFile[nPos1][MERGEF_PAGESOUT]
  cInRange  := aFile[nPos1][MERGEF_RANGEIN]
  cOutRange := aFile[nPos1][MERGEF_RANGEOUT]
  cPass     := aFile[nPos1][MERGEF_PASS]

  aFile[nPos1][MERGEF_NAME]       := aFile[nPos2][MERGEF_NAME]
  aFile[nPos1][MERGEF_PAGESIN]    := aFile[nPos2][MERGEF_PAGESIN]
  aFile[nPos1][MERGEF_PAGESOUT]   := aFile[nPos2][MERGEF_PAGESOUT]
  aFile[nPos1][MERGEF_RANGEIN]    := aFile[nPos2][MERGEF_RANGEIN]
  aFile[nPos1][MERGEF_RANGEOUT]   := aFile[nPos2][MERGEF_RANGEOUT]
  aFile[nPos1][MERGEF_PASS]       := aFile[nPos2][MERGEF_PASS]
  MergeWnd.Files.CellEx(nPos1, 1) := If(slMergeNames, HB_fNameName(aFile[nPos2][MERGEF_NAME]), aFile[nPos2][MERGEF_NAME])

  aFile[nPos2][MERGEF_NAME]       := cFile
  aFile[nPos2][MERGEF_PAGESIN]    := nInPages
  aFile[nPos2][MERGEF_PAGESOUT]   := nOutPages
  aFile[nPos2][MERGEF_RANGEIN]    := cInRange
  aFile[nPos2][MERGEF_RANGEOUT]   := cOutRange
  aFile[nPos2][MERGEF_PASS]       := cPass
  MergeWnd.Files.CellEx(nPos2, 1) := If(slMergeNames, HB_fNameName(cFile), cFile)

  MergeWnd.Files.VALUE := nPos2
  PdfMerge_ShowPages(@aFile, nPos2, @nTotalPages)

RETURN NIL


FUNCTION PdfMerge_ShowPages(/*@*/ aFile, nPos, /*@*/ nTotalPages)

  IF nPos == 0
    MergeWnd.PagesLabel.VALUE := ""
  ELSE
    MergeWnd.PagesLabel.FONTCOLOR := If(aFile[nPos][MERGEF_PAGESOUT] == 0, RED, BLACK)
    MergeWnd.PagesLabel.VALUE     := HB_NtoS(aFile[nPos][MERGEF_PAGESOUT]) + "/" + HB_NtoS(aFile[nPos][MERGEF_PAGESIN])
  ENDIF

  IF HB_IsNumeric(nTotalPages)
    MergeWnd.StatusLabel.FONTCOLOR := BLACK
    MergeWnd.StatusLabel.VALUE     := LangStr(LS_TotalPages) + " " + HB_NtoS(nTotalPages)
  ENDIF

RETURN NIL


FUNCTION PdfMerge_GetPages(/*@*/ aFile, /*@*/ nTotalPages)
  LOCAL aEvenOdd := {"", "even", "odd"}
  LOCAL aRotate  := {"", "right", "down", "left"}
  LOCAL nPos
  LOCAL cRanges
  LOCAL aRange
  LOCAL nRange
  LOCAL nPageTokens
  LOCAL nPage1, nPage2
  LOCAL nPages
  LOCAL nEvenOdd
  LOCAL nRotate

  IF GetFocus() != MergeWnd.RangesTBox.HANDLE
    RETURN NIL
  ENDIF

  nPos        := MergeWnd.Files.VALUE
  nTotalPages -= aFile[nPos][MERGEF_PAGESOUT]

  aFile[nPos][MERGEF_PAGESOUT] := 0
  aFile[nPos][MERGEF_RANGEIN]  := MergeWnd.RangesTBox.VALUE
  aFile[nPos][MERGEF_RANGEOUT] := ""
  aFile[nPos][MERGEF_RANGEERR] := ""

  cRanges := HB_UTF8StrTran(AllTrim(aFile[nPos][MERGEF_RANGEIN]), ";", ",")
  aRange  := HB_aTokens(cRanges, ",")

  FOR nRange := 1 TO Len(aRange)
    IF (nPageTokens := HB_TokenCount(aRange[nRange], "-")) > 2
      aFile[nPos][MERGEF_PAGESOUT] := 0
      EXIT
    ENDIF

    nPage1 := PdfMerge_GetPage1(AllTrim(HB_TokenGet(aRange[nRange], 1, "-")), aFile[nPos][MERGEF_PAGESIN], @nEvenOdd, @nRotate)

    IF nPage1 == 0
      aFile[nPos][MERGEF_PAGESOUT] := nPage1
      EXIT
    ENDIF

    IF nPageTokens == 1
      IF nPage1 > 0
        IF (nEvenOdd == 1) .and. ((nPage1 % 2) == 0) .or. (nEvenOdd == 2) .and. ((nPage1 % 2) == 1)
          aFile[nPos][MERGEF_PAGESOUT] := 0
          EXIT
        ENDIF

        aFile[nPos][MERGEF_PAGESOUT] += 1
        aFile[nPos][MERGEF_RANGEOUT] += " " + HB_NtoS(nPage1) + aEvenOdd[nEvenOdd + 1] + aRotate[nRotate + 1]
      ELSE
        nPages := PdfMerge_GetPagesInRange(1, aFile[nPos][MERGEF_PAGESIN], nEvenOdd)

        IF nPages == 0
          aFile[nPos][MERGEF_PAGESOUT] := nPages
          EXIT
        ENDIF

        IF Len(aRange) == 1
          aFile[nPos][MERGEF_PAGESOUT] := nPages
          aFile[nPos][MERGEF_RANGEOUT] := aEvenOdd[nEvenOdd + 1] + aRotate[nRotate + 1]
        ELSE
          aFile[nPos][MERGEF_PAGESOUT] += nPages
          aFile[nPos][MERGEF_RANGEOUT] += " " + HB_NtoS(1) + "-" + HB_NtoS(aFile[nPos][MERGEF_PAGESIN]) + aEvenOdd[nEvenOdd + 1] + aRotate[nRotate + 1]
        ENDIF
      ENDIF
    ELSE
      IF (nPage1 < 1) .or. (nEvenOdd != 0) .or. (nRotate != 0)
        aFile[nPos][MERGEF_PAGESOUT] := 0
        EXIT
      ENDIF

      nPage2 := PdfMerge_GetPage1(AllTrim(HB_TokenGet(aRange[nRange], 2, "-")), aFile[nPos][MERGEF_PAGESIN], @nEvenOdd, @nRotate)

      IF nPage2 < 1
        aFile[nPos][MERGEF_PAGESOUT] := 0
        EXIT
      ENDIF

      nPages := PdfMerge_GetPagesInRange(nPage1, nPage2, nEvenOdd)

      IF nPages == 0
        aFile[nPos][MERGEF_PAGESOUT] := nPages
        EXIT
      ENDIF

      aFile[nPos][MERGEF_PAGESOUT] += nPages
      aFile[nPos][MERGEF_RANGEOUT] += " " + HB_NtoS(nPage1) + "-" + HB_NtoS(nPage2) + aEvenOdd[nEvenOdd + 1] + aRotate[nRotate + 1]
    ENDIF
  NEXT //nRange

  IF aFile[nPos][MERGEF_PAGESOUT] == 0
    aFile[nPos][MERGEF_RANGEERR] := If(Empty(aRange[nRange]), aFile[nPos][MERGEF_RANGEIN], aRange[nRange])
  ELSE
    nTotalPages += aFile[nPos][MERGEF_PAGESOUT]
  ENDIF

  PdfMerge_ShowPages(@aFile, nPos, @nTotalPages)

RETURN NIL


FUNCTION PdfMerge_GetPage1(cStr, nPageLast, /*@*/ nEvenOdd, /*@*/ nRotate)
  LOCAL lReverse
  LOCAL nPage
  LOCAL n

  IF HB_UTF8Left(cStr, 1) == "!"
    lReverse := .T.
    cStr     := HB_UTF8SubStr(cStr, 2)
  ELSE
    lReverse := .F.
  ENDIF

  IF HMG_StrCmp(HB_UTF8Left(cStr, 1), "z", .F.) == 0
    nPage := nPageLast
    cStr  := HB_UTF8SubStr(cStr, 2)
  ELSE
    n := 1

    DO WHILE IsDigit(HB_UTF8SubStr(cStr, n, 1))
      ++n
    ENDDO

    IF --n == 0
      nPage := If(lReverse, 0, -1)
    ELSE
      nPage := Val(HB_UTF8SubStr(cStr, 1, n))

      IF nPage > 0
        IF nPage > nPageLast
          nPage := 0
        ELSE
          cStr := HB_UTF8SubStr(cStr, n + 1)
        ENDIF
      ENDIF
    ENDIF
  ENDIF

  IF nPage != 0
    IF lReverse
      nPage := nPageLast - nPage + 1
    ENDIF

    SWITCH cStr
      CASE ""
        nEvenOdd := 0
        nRotate  := 0
        EXIT
      CASE "\"
        nEvenOdd := 1
        nRotate  := 0
        EXIT
      CASE "/"
        nEvenOdd := 2
        nRotate  := 0
        EXIT
      CASE ">"
        nEvenOdd := 0
        nRotate  := 1
        EXIT
      CASE "_"
        nEvenOdd := 0
        nRotate  := 2
        EXIT
      CASE "<"
        nEvenOdd := 0
        nRotate  := 3
        EXIT
      CASE "\>"
        nEvenOdd := 1
        nRotate  := 1
        EXIT
      CASE "\_"
        nEvenOdd := 1
        nRotate  := 2
        EXIT
      CASE "\<"
        nEvenOdd := 1
        nRotate  := 3
        EXIT
      CASE "/>"
        nEvenOdd := 2
        nRotate  := 1
        EXIT
      CASE "/_"
        nEvenOdd := 2
        nRotate  := 2
        EXIT
      CASE "/<"
        nEvenOdd := 2
        nRotate  := 3
        EXIT
      OTHERWISE
        nPage := 0
    ENDSWITCH
  ENDIF

RETURN nPage


FUNCTION PdfMerge_GetPagesInRange(nPage1, nPage2, nEvenOdd)
  LOCAL nPages

  IF nEvenOdd == 0
    nPages := Abs(nPage1 - nPage2) + 1
  ELSEIF nEvenOdd == 1
    nPages := Round((Abs(nPage1 - nPage2) + (nPage1 % 2) + (nPage2 % 2)) / 2, 0)
  ELSE
    nPages := Round((Abs(nPage1 - nPage2) + (1 - nPage1 % 2) + (1 - nPage2 % 2)) / 2, 0)
  ENDIF

RETURN nPages


FUNCTION PdfSplit()
  LOCAL cFileName
  LOCAL nPages
  LOCAL cPass
  LOCAL aColor
  LOCAL nRow
  LOCAL nCol
  LOCAL nHFocus
  LOCAL nEventID

  IF IsWindowActive(SplitWnd)
    IF IsWindowActive(MergeWnd)
      MergeWnd.MINIMIZE
    ENDIF

    IF IsWindowActive(BooksWnd)
      BooksWnd.MINIMIZE
    ENDIF

    SplitWnd.RESTORE
    RETURN NIL
  ENDIF

  nPages    := Sumatra_PageCount(PanelName())
  cFileName := If(nPages == 0, "", Sumatra_FileName(PanelName()))
  cPass     := ""
  aColor    := ColorArray(GetSysColor(15 /*COLOR_BTNFACE*/))
  nRow      := GetProperty(PanelName(), "ROW")
  nCol      := GetProperty(PanelName(), "COL")
  ClientToScreen(PDFviewWnd.HANDLE, @nCol, @nRow)

  DEFINE WINDOW SplitWnd;
    ROW    nRow;
    COL    nCol;
    WIDTH  470 + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;
    HEIGHT 338 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(LS_SplitIntoPages, .T.);
    CHILD;
    NOMAXIMIZE;
    NOSIZE;
    ON GOTFOCUS SetFocus(nHFocus);
    ON RELEASE  EventRemove(nEventID)

    DEFINE LABEL DocLabel
      ROW    10
      COL    10
      WIDTH  450
      HEIGHT 13
      VALUE  LangStr(LS_Document, .T.) + ":"
    END LABEL

    DEFINE TEXTBOX DocTBox
      ROW               25
      COL               10
      WIDTH             430
      HEIGHT            21
      VALUE             cFileName
      DATATYPE          CHARACTER
      READONLY          .T.
      DISABLEDBACKCOLOR aColor
      ONGOTFOCUS        (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE BUTTON DocButton
      ROW        24
      COL        440
      WIDTH      20
      HEIGHT     23
      CAPTION    "..."
      ACTION     PdfSplit_GetFile(@cFileName, @nPages, @cPass)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON

    DEFINE LABEL RangesLabel
      ROW    56
      COL    10
      WIDTH  200
      HEIGHT 13
      VALUE  LangStr(LS_PageRanges) + ":"
    END LABEL

    DEFINE LABEL PagesLabel
      ROW       56
      COL       340
      WIDTH     100
      HEIGHT    13
      ALIGNMENT RIGHT
      VALUE     If(nPages > 0, HB_NtoS(nPages) + "/" + HB_NtoS(nPages), "")
    END LABEL

    DEFINE TEXTBOX RangesTBox
      ROW        71
      COL        10
      WIDTH      430
      HEIGHT     21
      DATATYPE   CHARACTER
      ONCHANGE   (PdfSplit_GetPages(nPages), (SplitWnd.StatusLabel.VALUE := ""))
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE BUTTON RangesButton
      ROW        70
      COL        440
      WIDTH      20
      HEIGHT     23
      CAPTION    "?"
      ACTION     PDFtk_PageRangesHelp(.F., SplitWnd.RangesTBox.HANDLE)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON

    DEFINE LABEL OutDirLabel
      ROW    102
      COL    10
      WIDTH  450
      HEIGHT 13
      VALUE  LangStr(LS_OutputDir)
    END LABEL

    DEFINE TEXTBOX OutDirTBox
      ROW               117
      COL               10
      WIDTH             430
      HEIGHT            21
      VALUE             HB_fNameDir(cFileName)
      DATATYPE          CHARACTER
      READONLY          .T.
      DISABLEDBACKCOLOR aColor
      ONGOTFOCUS        (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE BUTTON OutDirButton
      ROW        116
      COL        440
      WIDTH      20
      HEIGHT     23
      CAPTION    "..."
      ACTION     PdfSplit_GetOutDir()
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON

    DEFINE LABEL OutFilesLabel
      ROW    148
      COL    10
      WIDTH  450
      HEIGHT 13
      VALUE  LangStr(LS_TargetFiles)
    END LABEL

    DEFINE EDITBOX OutFilesEBox
      ROW               163
      COL               10
      WIDTH             450
      HEIGHT            60
      READONLY          .T.
      DISABLEDBACKCOLOR aColor
      VSCROLLBAR        .F.
      HSCROLLBAR        .F.
      ONGOTFOCUS        (nHFocus := This.HANDLE)
    END EDITBOX

    DEFINE FRAME PassFrame
      ROW     233
      COL     10
      WIDTH   450
      HEIGHT  61
      CAPTION LangStr(LS_PassProtect)
    END FRAME

    DEFINE LABEL OwnPassLabel
      ROW    248
      COL    20
      WIDTH  150
      HEIGHT 13
      VALUE  LangStr(LS_OwnerPass)
    END LABEL

    DEFINE TEXTBOX OwnPassTBox
      ROW        263
      COL        20
      WIDTH      150
      HEIGHT     21
      MAXLENGTH  32
      DATATYPE   CHARACTER
      PASSWORD   (! slPassShow)
      ONCHANGE   (SplitWnd.StatusLabel.VALUE := "")
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE LABEL UserPassLabel
      ROW    248
      COL    180
      WIDTH  150
      HEIGHT 13
      VALUE  LangStr(LS_UserPass)
    END LABEL

    DEFINE TEXTBOX UserPassTBox
      ROW        263
      COL        180
      WIDTH      150
      HEIGHT     21
      MAXLENGTH  32
      DATATYPE   CHARACTER
      PASSWORD   (! slPassShow)
      ONCHANGE   (SplitWnd.StatusLabel.VALUE := "")
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE CHECKBOX PassShowCBox
      ROW        268
      COL        340
      WIDTH      110
      HEIGHT     16
      VALUE      slPassShow
      CAPTION    LangStr(LS_ShowPass)
      ONCHANGE   ((slPassShow := SplitWnd.PassShowCBox.VALUE), ;
                   SendMessage(SplitWnd.OwnPassTBox.HANDLE,  0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), SplitWnd.OwnPassTBox.REDRAW, ;
                   SendMessage(SplitWnd.UserPassTBox.HANDLE, 0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), SplitWnd.UserPassTBox.REDRAW)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END CHECKBOX

    DEFINE LABEL StatusLabel
      ROW       315
      COL       10
      WIDTH     260
      HEIGHT    13
      VALUE     ""
      FONTCOLOR RED
    END LABEL

    DEFINE BUTTON MakeButton
      ROW         305
      COL         290
      WIDTH       80
      HEIGHT      23
      CAPTION     LangStr(LS_Make)
      ACTION      PDFtk_Split(cFileName, nPages, cPass)
      ONGOTFOCUS  (nHFocus := This.HANDLE)
      ONLOSTFOCUS SetDefPushButton(This.HANDLE, .F.)
    END BUTTON

    DEFINE BUTTON CloseButton
      ROW     305
      COL     380
      WIDTH   80
      HEIGHT  23
      CAPTION LangStr(LS_Close)
      ACTION  SplitWnd.RELEASE
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON
  END WINDOW

  PdfSplit_SetOutFiles(cFileName, nPages)
  HMG_ChangeWindowStyle(SplitWnd.PassFrame.HANDLE, 0x0300 /*BS_CENTER*/, NIL, NIL, .T.)

  SplitWnd.MakeButton.ENABLED := (! Empty(cFileName))
  SplitWnd.DocTBox.SETFOCUS

  nEventID := EventCreate({|| If(EventWPARAM() == VK_ESCAPE, (SplitWnd.MakeButton.SETFOCUS, PostMessage(SplitWnd.HANDLE, 273 /*WM_COMMAND*/, IDCANCEL, 0)), NIL)}, SplitWnd.OutFilesEBox.HANDLE, WM_KEYDOWN)

  ON KEY F1              OF SplitWnd ACTION If(GetFocus() == SplitWnd.RangesTBox.HANDLE, PDFtk_PageRangesHelp(.F., SplitWnd.RangesTBox.HANDLE), NIL)
  ON KEY F6              OF SplitWnd ACTION ModelessSetFocus(ThisWindow.NAME)
  ON KEY CONTROL+SHIFT+B OF SplitWnd ACTION If(IsWindowActive(BooksWnd), (SplitWnd.MINIMIZE, BooksWnd.RESTORE), NIL)
  ON KEY CONTROL+SHIFT+M OF SplitWnd ACTION If(IsWindowActive(MergeWnd), (SplitWnd.MINIMIZE, MergeWnd.RESTORE), NIL)
  ON KEY CONTROL+SHIFT+S OF SplitWnd ACTION SplitWnd.MINIMIZE

  SplitWnd.ACTIVATE

RETURN NIL


FUNCTION PdfSplit_SetOutFiles(cFileName, nPages)
  LOCAL cText := ""
  LOCAL cFile
  LOCAL cExt
  LOCAL nPagesLen

  IF nPages > 0
    cFile     := HB_fNameName(cFileName)
    cExt      := HB_fNameExt(cFileName)
    nPagesLen := Len(HB_NtoS(nPages))
    cText     += cFile + "_" + StrZero(1, nPagesLen) + cExt

    IF nPages > 1
      cText += CRLF + cFile + "_" + StrZero(2, nPagesLen) + cExt
      IF nPages > 2
        IF nPages < 5
          cText += CRLF + cFile + "_" + StrZero(3, nPagesLen) + cExt
          IF nPages == 4
            cText += CRLF + cFile + "_" + StrZero(4, nPagesLen) + cExt
          ENDIF
        ELSE
          cText += CRLF + "..." + CRLF + cFile + "_" + StrZero(nPages, nPagesLen) + cExt
        ENDIF
      ENDIF
    ENDIF
  ENDIF

  SplitWnd.OutFilesEBox.VALUE := cText

RETURN NIL


FUNCTION PdfSplit_GetFile(/*@*/ cFileName, /*@*/ nPages, /*@*/ cPass)
  LOCAL cFileNew
  LOCAL nPagesNew
  LOCAL cPassNew
  LOCAL cDir
  LOCAL n

  IF ! Empty(cFileName)
    cDir := HB_fNameDir(cFileName)
  ELSEIF Sumatra_PageCount(PanelName()) > 0
    cDir := HB_fNameDir(Sumatra_FileName(PanelName()))
  ELSE
    cDir := scFileDir
  ENDIF

  cFileNew  := GetFile({{"*.pdf", "*.pdf"}}, NIL, cDir, .F., .T.)
  nPagesNew := 0
  cPassNew  := ""

  IF (! Empty(cFileNew)) .and. (HMG_StrCmp(cFileNew, cFileName, .F.) != 0)
    FOR n := 1 TO Len(saTab)
      IF HMG_StrCmp(cFileNew, Sumatra_FileName(PanelName(saTab[n])), .F.) == 0
        nPagesNew := Sumatra_PageCount(PanelName(saTab[n]))
        EXIT
      ENDIF
    NEXT

    IF nPagesNew == 0
      SplitWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking)
      nPagesNew := PDFtk_PageCount(cFileNew, @cPassNew)
    ENDIF

    IF nPagesNew > 0
      cFileName := cFileNew
      nPages    := nPagesNew
      cPass     := cPassNew

      SplitWnd.DocTBox.VALUE    := cFileName
      SplitWnd.OutDirTBox.VALUE := HB_fNameDir(cFileName)

      PdfSplit_GetPages(nPages)
      PdfSplit_SetOutFiles(cFileName, nPages)

      SplitWnd.MakeButton.ENABLED := .T.
    ENDIF

    SplitWnd.StatusLabel.VALUE := ""
  ENDIF

RETURN NIL


FUNCTION PdfSplit_GetOutDir()
  LOCAL nRow := SplitWnd.OutDirTBox.ROW + SplitWnd.OutDirTBox.HEIGHT
  LOCAL nCol := SplitWnd.OutDirTBox.COL
  LOCAL cDir

  ClientToScreen(SplitWnd.HANDLE, @nCol, @nRow)

  cDir := BrowseForFolder(CRLF + LangStr(LS_ChooseDir, .T.) + ":", BIF_NEWDIALOGSTYLE, NIL, NIL, SplitWnd.OutDirTBox.VALUE, nRow + 3, nCol)

  IF ! Empty(cDir)
    SplitWnd.OutDirTBox.VALUE  := DirSepAdd(cDir)
    SplitWnd.StatusLabel.VALUE := ""
  ENDIF

RETURN NIL


FUNCTION PdfSplit_GetPages(nPages)
  LOCAL aPage  := Array(nPages)
  LOCAL aRange := HB_aTokens(HB_UTF8StrTran(AllTrim(SplitWnd.RangesTBox.VALUE), ";", ","), ",")
  LOCAL nRange
  LOCAL nPageTokens
  LOCAL cPage1, cPage2
  LOCAL nPage1, nPage2
  LOCAL nPage
  LOCAL nEvenOdd
  LOCAL lReverse1, lReverse2
  LOCAL nStep
  LOCAL xRetVal

  FOR nRange := 1 TO Len(aRange)
    IF (nPageTokens := HB_TokenCount(aRange[nRange], "-")) > 2
      xRetVal := aRange[nRange]
      EXIT
    ENDIF

    cPage1 := AllTrim(HB_TokenGet(aRange[nRange], 1, "-"))

    IF (nPageTokens == 1) .and. ((cPage1 == "") .or. (cPage1 == "/") .or. (cPage1 == "\"))
      nPageTokens := 2
      cPage2 := HB_NtoS(nPages) + HB_UTF8Right(cPage1, 1)
      cPage1 := "1"
    ELSEIF nPageTokens == 2
      cPage2 := AllTrim(HB_TokenGet(aRange[nRange], 2, "-"))
    ENDIF

    IF nPageTokens == 1
      IF HB_UTF8Right(cPage1, 1) == "/"
        nEvenOdd := 2
        cPage1 := HB_StrShrink(cPage1)
      ELSEIF HB_UTF8Right(cPage1, 1) == "\"
        nEvenOdd := 1
        cPage1 := HB_StrShrink(cPage1)
      ELSE
        nEvenOdd := 0
      ENDIF
    ELSE
      IF HB_UTF8Right(cPage2, 1) == "/"
        nEvenOdd := 2
        cPage2 := HB_StrShrink(cPage2)
      ELSEIF HB_UTF8Right(cPage2, 1) == "\"
        nEvenOdd := 1
        cPage2 := HB_StrShrink(cPage2)
      ELSE
        nEvenOdd := 0
      ENDIF

      IF HB_UTF8Left(cPage2, 1) == "!"
        lReverse2 := .T.
        cPage2    := HB_UTF8SubStr(cPage2, 2)
      ELSE
        lReverse2 := .F.
      ENDIF

      IF HMG_StrCmp(cPage2, "z", .F.) == 0
        cPage2 := HB_NtoS(nPages)
      ENDIF
    ENDIF

    IF HB_UTF8Left(cPage1, 1) == "!"
      lReverse1 := .T.
      cPage1    := HB_UTF8SubStr(cPage1, 2)
    ELSE
      lReverse1 := .F.
    ENDIF

    IF HMG_StrCmp(cPage1, "z", .F.) == 0
      cPage1 := HB_NtoS(nPages)
    ENDIF

    IF (! IsDigitString(cPage1)) .or. (nPageTokens == 2) .and. (! IsDigitString(cPage2))
      xRetVal := aRange[nRange]
      EXIT
    ENDIF

    nPage1 := Val(cPage1)

    IF nPageTokens == 1
      lReverse2 := lReverse1
      nPage2    := nPage1
    ELSE
      nPage2 := Val(cPage2)
    ENDIF

    IF (nPage1 == 0) .or. (nPage1 > nPages) .or. (nPage2 == 0) .or. (nPage2 > nPages)
      xRetVal := aRange[nRange]
      EXIT
    ENDIF

    IF lReverse1
      nPage1 := nPages - nPage1 + 1
    ENDIF

    IF lReverse2
      nPage2 := nPages - nPage2 + 1
    ENDIF

    IF nEvenOdd == 0
      nStep := If(nPage1 <= nPage2, 1, -1)
    ELSEIF nEvenOdd == 1
      IF nPage1 <= nPage2
        nStep := 2
        IF (nPage1 % 2) == 0
          ++nPage1
        ENDIF
      ELSE
        nStep := -2
        IF (nPage1 % 2) == 0
          --nPage1
        ENDIF
      ENDIF
    ELSE
      IF nPage1 <= nPage2
        nStep := 2
        IF (nPage1 % 2) == 1
          ++nPage1
        ENDIF
      ELSE
        nStep := -2
        IF (nPage1 % 2) == 1
          --nPage1
        ENDIF
      ENDIF
    ENDIF

    FOR nPage := nPage1 TO nPage2 STEP nStep
      aPage[nPage] := nPage
    NEXT
  NEXT //nRange

  IF HB_IsNIL(xRetVal)
    FOR nPage := nPages TO 1 STEP -1
      IF HB_IsNIL(aPage[nPage])
        HB_aDel(aPage, nPage, .T.)
      ENDIF
    NEXT

    IF Empty(aPage)
      xRetVal := SplitWnd.RangesTBox.VALUE
    ELSE
      SplitWnd.PagesLabel.FONTCOLOR := BLACK
      SplitWnd.PagesLabel.VALUE := HB_NtoS(Len(aPage)) + "/" + HB_NtoS(nPages)
      xRetVal := aPage
    ENDIF
  ENDIF

  IF HB_IsString(xRetVal)
    SplitWnd.PagesLabel.FONTCOLOR := RED
    SplitWnd.PagesLabel.VALUE := "0/" + HB_NtoS(nPages)
  ENDIF

RETURN xRetVal


FUNCTION PdfBookmarks()
  LOCAL aColor
  LOCAL nRow
  LOCAL nCol
  LOCAL nHFocus

  IF IsWindowActive(BooksWnd)
    IF IsWindowActive(MergeWnd)
      MergeWnd.MINIMIZE
    ENDIF

    IF IsWindowActive(SplitWnd)
      SplitWnd.MINIMIZE
    ENDIF

    BooksWnd.RESTORE
    RETURN NIL
  ENDIF

  aColor := ColorArray(GetSysColor(15 /*COLOR_BTNFACE*/))
  nRow   := GetProperty(PanelName(), "ROW")
  nCol   := GetProperty(PanelName(), "COL")
  ClientToScreen(PDFviewWnd.HANDLE, @nCol, @nRow)

  DEFINE WINDOW BooksWnd;
    ROW    nRow;
    COL    nCol;
    WIDTH  470 + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;
    HEIGHT 258 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(LS_Bookmarks, .T.);
    CHILD;
    NOMAXIMIZE;
    NOSIZE;
    ON GOTFOCUS SetFocus(nHFocus)

    DEFINE LABEL DocLabel
      ROW    10
      COL    10
      WIDTH  450
      HEIGHT 13
      VALUE  LangStr(LS_Document, .T.) + ":"
    END LABEL

    DEFINE TEXTBOX DocTBox
      ROW               25
      COL               10
      WIDTH             430
      HEIGHT            21
      DATATYPE          CHARACTER
      READONLY          .T.
      DISABLEDBACKCOLOR aColor
      ONGOTFOCUS        (nHFocus := This.HANDLE)
      ONCHANGE          PdfBookmarks_ButtonsEnable()
    END TEXTBOX

    DEFINE BUTTON DocButton
      ROW        24
      COL        440
      WIDTH      20
      HEIGHT     23
      CAPTION    "..."
      ACTION     (BooksWnd.DocTBox.VALUE := PdfBookmarks_GetFile(BooksWnd.DocTBox.VALUE, ".pdf"))
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON

    DEFINE RADIOGROUP RadioRG
      ROW      50
      COL      10
      WIDTH    450
      SPACING  21
      VALUE    1
      OPTIONS  {LangStr(LS_SaveBooks), LangStr(LS_RemoveBooks), LangStr(LS_InsertBooks)}
      ONCHANGE (PdfBookmarks_ButtonsEnable(), (nHFocus := GetFocus()))
    END RADIOGROUP

    DEFINE TEXTBOX TxtTBox
      ROW               120
      COL               10
      WIDTH             430
      HEIGHT            21
      DATATYPE          CHARACTER
      DISABLEDBACKCOLOR aColor
      ONGOTFOCUS        (nHFocus := This.HANDLE)
      ONCHANGE          PdfBookmarks_ButtonsEnable()
    END TEXTBOX

    DEFINE BUTTON TxtButton
      ROW        119
      COL        440
      WIDTH      20
      HEIGHT     23
      CAPTION    "..."
      ACTION     (BooksWnd.TxtTBox.VALUE := PdfBookmarks_GetFile(BooksWnd.TxtTBox.VALUE, ".txt"))
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON

    DEFINE FRAME PassFrame
      ROW     153
      COL     10
      WIDTH   450
      HEIGHT  61
      CAPTION LangStr(LS_PassProtect)
    END FRAME

    DEFINE LABEL OwnPassLabel
      ROW    168
      COL    20
      WIDTH  150
      HEIGHT 13
      VALUE  LangStr(LS_OwnerPass)
    END LABEL

    DEFINE TEXTBOX OwnPassTBox
      ROW               183
      COL               20
      WIDTH             150
      HEIGHT            21
      MAXLENGTH         32
      DATATYPE          CHARACTER
      PASSWORD          (! slPassShow)
      DISABLEDBACKCOLOR aColor
      ONGOTFOCUS        (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE LABEL UserPassLabel
      ROW    168
      COL    180
      WIDTH  150
      HEIGHT 13
      VALUE  LangStr(LS_UserPass)
    END LABEL

    DEFINE TEXTBOX UserPassTBox
      ROW               183
      COL               180
      WIDTH             150
      HEIGHT            21
      MAXLENGTH         32
      DATATYPE          CHARACTER
      PASSWORD          (! slPassShow)
      DISABLEDBACKCOLOR aColor
      ONGOTFOCUS        (nHFocus := This.HANDLE)
    END TEXTBOX

    DEFINE CHECKBOX PassShowCBox
      ROW        188
      COL        340
      WIDTH      110
      HEIGHT     16
      VALUE      slPassShow
      CAPTION    LangStr(LS_ShowPass)
      ONCHANGE   ((slPassShow := BooksWnd.PassShowCBox.VALUE), ;
                   SendMessage(BooksWnd.OwnPassTBox.HANDLE,  0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), BooksWnd.OwnPassTBox.REDRAW, ;
                   SendMessage(BooksWnd.UserPassTBox.HANDLE, 0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), BooksWnd.UserPassTBox.REDRAW)
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END CHECKBOX

    DEFINE LABEL StatusLabel
      ROW       235
      COL       10
      WIDTH     260
      HEIGHT    13
      VALUE     ""
      FONTCOLOR RED
    END LABEL

    DEFINE BUTTON MakeButton
      ROW        225
      COL        290
      WIDTH      80
      HEIGHT     23
      CAPTION    LangStr(LS_Make)
      ACTION     PDFtk_Bookmarks()
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON

    DEFINE BUTTON CloseButton
      ROW     225
      COL     380
      WIDTH   80
      HEIGHT  23
      CAPTION LangStr(LS_Close)
      ACTION  BooksWnd.RELEASE
      ONGOTFOCUS (nHFocus := This.HANDLE)
    END BUTTON
  END WINDOW

  BooksWnd.DocTBox.VALUE := If(Sumatra_PageCount(PanelName()) == 0, "", Sumatra_FileName(PanelName()))

  HMG_ChangeWindowStyle(BooksWnd.PassFrame.HANDLE, 0x0300 /*BS_CENTER*/, NIL, NIL, .T.)
  PdfBookmarks_ButtonsEnable()
  BooksWnd.DocTBox.SETFOCUS


  ON KEY F1              OF BooksWnd ACTION NIL
  ON KEY F6              OF BooksWnd ACTION ModelessSetFocus(ThisWindow.NAME)
  ON KEY CONTROL+SHIFT+B OF BooksWnd ACTION BooksWnd.MINIMIZE
  ON KEY CONTROL+SHIFT+M OF BooksWnd ACTION If(IsWindowActive(MergeWnd), (BooksWnd.MINIMIZE, MergeWnd.RESTORE), NIL)
  ON KEY CONTROL+SHIFT+S OF BooksWnd ACTION If(IsWindowActive(SplitWnd), (BooksWnd.MINIMIZE, SplitWnd.RESTORE), NIL)

  BooksWnd.ACTIVATE

RETURN NIL


FUNCTION PdfBookmarks_ButtonsEnable()

  BooksWnd.TxtTBox.ENABLED      := (BooksWnd.RadioRG.VALUE == 3)
  BooksWnd.TxtButton.ENABLED    := (BooksWnd.RadioRG.VALUE == 3)
  BooksWnd.OwnPassTBox.ENABLED  := (BooksWnd.RadioRG.VALUE > 1)
  BooksWnd.UserPassTBox.ENABLED := (BooksWnd.RadioRG.VALUE > 1)
  BooksWnd.MakeButton.ENABLED   := (! Empty(BooksWnd.DocTBox.VALUE)) .and. ((BooksWnd.RadioRG.VALUE < 3) .or. (! Empty(BooksWnd.TxtTBox.VALUE)))

RETURN NIL


FUNCTION PdfBookmarks_GetFile(cFile, cExt)
  LOCAL cFileNew
  LOCAL cDir

  IF ! Empty(cFile)
    cDir := HB_fNameDir(cFile)
  ELSEIF Sumatra_PageCount(PanelName()) > 0
    cDir := HB_fNameDir(Sumatra_FileName(PanelName()))
  ELSE
    cDir := scFileDir
  ENDIF

  cFileNew := GetFile({{"*" + cExt, "*" + cExt}}, NIL, cDir, .F., .T.)

  IF Empty(cFileNew)
    cFileNew := cFile
  ENDIF

RETURN cFileNew


/*
  PDFtk v2.02 doesn't support Unicode file names.
  So we use temporary copy of files with ASCII names.
*/
FUNCTION PDFtk_Merge(/*@*/ aFile, /*@*/ nTotalPages)
  LOCAL cPDFtkName
  LOCAL cExt
  LOCAL cTmpDir
  LOCAL cSourceFile
  LOCAL cTargetFile
  LOCAL cInputPass
  LOCAL cOwnPass
  LOCAL cUserPass
  LOCAL cStdErr
  LOCAL nExitCode
  LOCAL nFile, nFiles, nFileLast, nFileMax
  LOCAL nRun, nRuns
  LOCAL nToken, nRangeTokens, cRanges
  LOCAL aRect
  LOCAL lOpenAtOnce
  LOCAL n

  nFiles := Len(aFile)

  IF nFiles == 0
    RETURN NIL
  ENDIF

  nFileLast := 0
  nFileMax  := 10

  FOR nFile := 1 TO nFiles
    IF ! HB_FileExists(aFile[nFile][MERGEF_NAME])
      MergeWnd.Files.VALUE := nFile
      MsgWin(aFile[nFile][MERGEF_NAME] + CRLF2 + LangStr(LS_NoFile))
      RETURN NIL
    ENDIF

    IF aFile[nFile][MERGEF_PAGESOUT] == 0
      MergeWnd.Files.VALUE := nFile
      MsgWin(LangStr(LS_RangesError))
      MergeWnd.RangesTBox.SETFOCUS
      HMG_EditControlSetSel(MergeWnd.RangesTBox.HANDLE, ;
                            HB_UAt(aFile[nFile][MERGEF_RANGEERR], MergeWnd.RangesTBox.VALUE) - 1, ;
                            HB_UAt(aFile[nFile][MERGEF_RANGEERR], MergeWnd.RangesTBox.VALUE) + HMG_Len(aFile[nFile][MERGEF_RANGEERR]) - 1)
      RETURN NIL
    ENDIF

    nFileLast += Int(HB_TokenCount(aFile[nFile][MERGEF_RANGEOUT]) / nFileMax) + If((HB_TokenCount(aFile[nFile][MERGEF_RANGEOUT]) % nFileMax) == 0, 0, 1)
  NEXT

  IF Empty(cPDFtkName := PDFtk_ExeName())
    RETURN NIL
  ENDIF

  cExt := HB_fNameExt(aFile[1][MERGEF_NAME])

  IF Empty(cTargetFile := PutFile({{"*" + cExt, "*" + cExt}}, NIL, HB_fNameDir(aFile[1][MERGEF_NAME]), .T., FileUniqueName(aFile[1][MERGEF_NAME]), cExt))
    RETURN NIL
  ENDIF

  nRun      := 0
  nRuns     := nFileLast + Int((nFileLast + (nFileMax - 3)) / (nFileMax - 1))
  nFileLast := 0
  cOwnPass  := If(Empty(MergeWnd.OwnPassTBox.VALUE), '', ' owner_pw "' + MergeWnd.OwnPassTBox.VALUE + '"')
  cUserPass := If(Empty(MergeWnd.UserPassTBox.VALUE), '', ' user_pw "' + MergeWnd.UserPassTBox.VALUE + '"')
  cTmpDir   := DirTmpCreate()

  MergeWnd.StatusLabel.FONTCOLOR := RED

  FOR nFile := 1 TO nFiles
    ++nFileLast
    MergeWnd.Files.VALUE := nFile
    MergeWnd.Files.REDRAW
    MergeWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking) + " (" + HB_NtoS(++nRun) + "/" + HB_NtoS(nRuns) + ")"

    IF HB_StrIsUTF8(aFile[nFile][MERGEF_NAME])
      cSourceFile := cTmpDir + "a" + cExt

      IF ! FileCopy(aFile[nFile][MERGEF_NAME], cSourceFile)
        MsgWin(LangStr(LS_FileCopyError) + CRLF2 + aFile[nFile][MERGEF_NAME] + CRLF + "=>" + CRLF + cSourceFile)
        nExitCode := -2
        EXIT
      ENDIF
    ELSE
      cSourceFile := aFile[nFile][MERGEF_NAME]
    ENDIF

    FOR n := 1 TO (nFile - 1)
      IF HMG_StrCmp(aFile[nFile][MERGEF_NAME], aFile[n][MERGEF_NAME], .F.) == 0
        aFile[nFile][MERGEF_PASS] := aFile[n][MERGEF_PASS]
      ENDIF
    NEXT

    nToken       := 1
    nRangeTokens := HB_TokenCount(aFile[nFile][MERGEF_RANGEOUT])
    cRanges      := ""
    cInputPass   := aFile[nFile][MERGEF_PASS]

    FOR n := 1 TO nFileMax
      cRanges += HB_TokenGet(aFile[nFile][MERGEF_RANGEOUT], nToken) + " "
      IF ++nToken > nRangeTokens
        EXIT
      ENDIF
    NEXT

    DO WHILE .T.
      MergeWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking) + " (" + HB_NtoS(nRun) + "/" + HB_NtoS(nRuns) + ")"

      IF (nFiles == 1) .and. (nRangeTokens <= nFileMax)
        nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cSourceFile + '" input_pw "' + cInputPass + '" cat ' + cRanges + ' output "' + cTmpDir + HB_NtoS(nFileLast) + cExt + '" allow AllFeatures' + cOwnPass + cUserPass, NIL, NIL, @cStdErr, .T.)
      ELSE
        nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cSourceFile + '" input_pw "' + cInputPass + '" cat ' + cRanges + ' output "' + cTmpDir + HB_NtoS(nFileLast) + cExt + '"', NIL, NIL, @cStdErr, .T.)
      ENDIF

      IF PDFtk_PassRequired(nExitCode, @cStdErr)
        aRect      := ListView_GetItemRect(MergeWnd.Files.HANDLE, nFile - 1)
        cInputPass := PDFtk_InputPassword(aFile[nFile][MERGEF_NAME], cInputPass, ClientToScreenRow(MergeWnd.Files.HANDLE, aRect[1] + aRect[4]) + 2, ClientToScreenCol(MergeWnd.Files.HANDLE, aRect[2]))

        IF ! HB_IsString(cInputPass)
          EXIT
        ENDIF
      ELSEIF nExitCode == 0
        IF (nFiles == 1) .and. (nRangeTokens <= nFileMax) .or. (nToken > nRangeTokens)
          aFile[nFile][MERGEF_PASS] := cInputPass
          EXIT
        ELSE
          ++nFileLast
          ++nRun
          cRanges := ""

          FOR n := 1 TO nFileMax
            cRanges += HB_TokenGet(aFile[nFile][MERGEF_RANGEOUT], nToken) + " "
            IF ++nToken > nRangeTokens
              EXIT
            ENDIF
          NEXT
        ENDIF
      ELSE
        IF nExitCode < 0
          MsgWin(LangStr(LS_CantRunPDFtk), LangStr(LS_PDFtkError))
        ELSE
          MsgWin(cStdErr, LangStr(LS_PDFtkError))
        ENDIF
        EXIT
      ENDIF
    ENDDO

    IF nExitCode != 0
      EXIT
    ENDIF
  NEXT //nFile

  IF (nExitCode == 0) .and. (nFileLast > 1)
    FOR nFile := 1 TO nFiles
      IF ! Empty(aFile[nFile][MERGEF_PASS])
        FileRecentAdd(aFile[nFile][MERGEF_NAME], NIL, aFile[nFile][MERGEF_PASS])
      ENDIF
    NEXT

    nFile  := 0
    nFiles := nFileLast

    DO WHILE .T.
      cSourceFile := ""

      FOR n := 1 TO nFileMax
        ++nFile
        cSourceFile += ' "' + cTmpDir + HB_NtoS(nFile) + cExt + '"'

        IF nFile == nFiles
          EXIT
        ENDIF
      NEXT

      MergeWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking) + " (" + HB_NtoS(++nRun) + "/" + HB_NtoS(nRuns) + ")"

      IF nFile == nFileLast
        ++nFileLast
        nExitCode := HB_ProcessRun('"' + cPDFtkName + '"' + cSourceFile + ' cat output "' + cTmpDir + HB_NtoS(nFileLast) + cExt  + '" allow AllFeatures' + cOwnPass + cUserPass, NIL, NIL, @cStdErr, .T.)
      ELSE
        ++nFileLast
        nExitCode := HB_ProcessRun('"' + cPDFtkName + '"' + cSourceFile + ' cat output "' + cTmpDir + HB_NtoS(nFileLast) + cExt + '"', NIL, NIL, @cStdErr, .T.)
      ENDIF

      IF nExitCode == 0
        IF nFile == nFiles
          IF (nFileLast - nFiles) > 1
            nFiles := nFileLast
          ELSE
            EXIT
          ENDIF
        ELSEIF ((nFiles - nFile) < nFileMax) .and. ((nFileLast - nFile) <= nFileMax)
          FOR n := (nFile + 1) TO nFiles
            ++nFileLast
            fRename(cTmpDir + HB_NtoS(n) + cExt, cTmpDir + HB_NtoS(nFileLast) + cExt)
          NEXT

          nFile  := nFiles
          nFiles := nFileLast
        ENDIF
      ELSE
        IF nExitCode < 0
          MsgWin(LangStr(LS_CantRunPDFtk), LangStr(LS_PDFtkError))
        ELSE
          MsgWin(cStdErr, LangStr(LS_PDFtkError))
        ENDIF
        EXIT
      ENDIF
    ENDDO
  ENDIF

  IF nExitCode == 0
    cSourceFile := cTmpDir + HB_NtoS(nFileLast) + cExt

    IF FileCopy(cSourceFile, cTargetFile)
      MergeWnd.StatusLabel.VALUE := LangStr(LS_Done)
      lOpenAtOnce  := slOpenAtOnce
      slOpenAtOnce := .F.
      scFileDir    := HB_fNameDir(cTargetFile)

      Files_Refresh(HB_fNameNameExt(cTargetFile))

      slOpenAtOnce := lOpenAtOnce
    ELSE
      PdfMerge_ShowPages(@aFile, MergeWnd.Files.VALUE, @nTotalPages)
      MsgWin(LangStr(LS_FileCopyError) + CRLF2 + cSourceFile + CRLF + "=>" + CRLF + cTargetFile)
    ENDIF
  ELSE
    PdfMerge_ShowPages(@aFile, MergeWnd.Files.VALUE, @nTotalPages)
  ENDIF

  HB_DirRemoveAll(cTmpDir)

RETURN NIL


FUNCTION PDFtk_Split(cFileName, nPages, cInputPass)
  LOCAL cPDFtkName
  LOCAL aPage
  LOCAL cPage
  LOCAL nPageFirst
  LOCAL nPagesLen
  LOCAL cFile
  LOCAL cExt
  LOCAL cOutDir
  LOCAL cTmpDir
  LOCAL cTmpFileName
  LOCAL cOutFileName
  LOCAL cOwnPass
  LOCAL cUserPass
  LOCAL cStdErr
  LOCAL nExitCode
  LOCAL nChoice1, nChoice2
  LOCAL lOpenAtOnce
  LOCAL n

  IF ! HB_FileExists(cFileName)
    MsgWin(cFileName + CRLF2 + LangStr(LS_NoFile))
    RETURN NIL
  ENDIF

  IF Empty(cPDFtkName := PDFtk_ExeName())
    RETURN NIL
  ENDIF

  aPage := PdfSplit_GetPages(nPages)

  IF HB_IsString(aPage)
    MsgWin(LangStr(LS_RangesError))
    SplitWnd.RangesTBox.SETFOCUS
    HMG_EditControlSetSel(SplitWnd.RangesTBox.HANDLE, HB_UAt(aPage, SplitWnd.RangesTBox.VALUE) - 1, HB_UAt(aPage, SplitWnd.RangesTBox.VALUE) + HMG_Len(aPage) - 1)
    RETURN NIL
  ENDIF

  cExt    := HB_fNameExt(cFileName)
  cTmpDir := DirTmpCreate()

  SplitWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking)

  IF HB_StrIsUTF8(cFileName)
    cTmpFileName := cTmpDir + "a" + cExt

    IF ! FileCopy(cFileName, cTmpFileName)
      HB_DirRemoveAll(cTmpDir)
      MsgWin(LangStr(LS_FileCopyError) + CRLF2 + cFileName + CRLF + "=>" + CRLF + cTmpFileName)
      SplitWnd.StatusLabel.VALUE := ""
      RETURN NIL
    ENDIF
  ELSE
    cTmpFileName := cFileName
  ENDIF

  IF Empty(cInputPass)
    cInputPass := FileRecentGetPass(cFileName)
  ENDIF

  cOwnPass  := If(Empty(SplitWnd.OwnPassTBox.VALUE), '', ' owner_pw "' + SplitWnd.OwnPassTBox.VALUE + '"')
  cUserPass := If(Empty(SplitWnd.UserPassTBox.VALUE), '', ' user_pw "' + SplitWnd.UserPassTBox.VALUE + '"')

  DO WHILE .T.
    nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cTmpFileName + '" input_pw "' + cInputPass + '" burst output "' + cTmpDir + '%0' + HB_NtoS(Len(HB_NtoS(nPages))) + 'd' + cExt + '" allow AllFeatures' + cOwnPass + cUserPass, NIL, NIL, @cStdErr, .T.)

    IF PDFtk_PassRequired(nExitCode, @cStdErr)
      cInputPass := PDFtk_InputPassword(cFileName, cInputPass, ClientToScreenRow(SplitWnd.HANDLE, SplitWnd.DocTBox.ROW + SplitWnd.DocTBox.HEIGHT) + 3, ClientToScreenCol(SplitWnd.HANDLE, SplitWnd.DocTBox.COL))

      IF ! HB_IsString(cInputPass)
        SplitWnd.StatusLabel.VALUE := ""
        EXIT
      ENDIF
    ELSE
      SplitWnd.StatusLabel.VALUE := ""

      IF nExitCode < 0
        MsgWin(LangStr(LS_CantRunPDFtk), LangStr(LS_PDFtkError))
      ELSEIF nExitCode > 0
        MsgWin(cStdErr, LangStr(LS_PDFtkError))
      ENDIF
      EXIT
    ENDIF
  ENDDO

  IF nExitCode == 0
    nPagesLen    := Len(HB_NtoS(nPages))
    cFile        := HB_fNameName(cFileName)
    cOutDir      := SplitWnd.OutDirTBox.VALUE
    nChoice1     := 1
    nChoice2     := 1
    nPageFirst   := 0
    lOpenAtOnce  := slOpenAtOnce
    slOpenAtOnce := .F.

    HB_DirBuild(cOutDir)

    FOR n := 1 TO Len(aPage)
      cPage        := StrZero(aPage[n], nPagesLen)
      cTmpFileName := cTmpDir + cPage + cExt
      cOutFileName := cOutDir + cFile + "_" + cPage + cExt

      SplitWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_CopyTarget) + " (" + HB_NtoS(n) + "/" + HB_NtoS(Len(aPage)) + ")"

      IF HB_FileExists(cOutFileName) .and. (nChoice1 != 2)
        nChoice1 := MsgWin(cOutFileName + CRLF2 + LangStr(LS_FileOverwrite), NIL, {LangStr(LS_Yes), LangStr(LS_YesForAll), LangStr(LS_Skip), LangStr(LS_Cancel)})
      ENDIF

      DO WHILE (nChoice1 == 1) .or. (nChoice1 == 2)
        IF FileCopy(cTmpFileName, cOutFileName)
          IF nPageFirst == 0
            nPageFirst := aPage[n]
          ENDIF
          EXIT
        ELSE
          nChoice2 := MsgWin(LangStr(LS_FileCopyError) + CRLF2 + cTmpFileName + CRLF + "=>" + CRLF + cOutFileName, NIL, {LangStr(LS_Repeat), LangStr(LS_Skip), LangStr(LS_Cancel)})
          IF (nChoice2 != 1)
            EXIT
          ENDIF
        ENDIF
      ENDDO

      IF (nChoice1 == 4) .or. (nChoice2 == 3)
        EXIT
      ENDIF
    NEXT

    IF ! Empty(cInputPass)
      FileRecentAdd(cFileName, NIL, cInputPass)
    ENDIF

    IF nPageFirst == 0
      SplitWnd.StatusLabel.VALUE := ""
    ELSE
      SplitWnd.StatusLabel.VALUE := LangStr(LS_Done)
      scFileDir := cOutDir
      Files_Refresh(cFile + "_" + StrZero(nPageFirst, nPagesLen) + cExt)
    ENDIF

    slOpenAtOnce := lOpenAtOnce
  ENDIF

  HB_DirRemoveAll(cTmpDir)

RETURN NIL


FUNCTION PDFtk_Bookmarks()
  LOCAL cPDFtkName := PDFtk_ExeName()
  LOCAL cPdfFile
  LOCAL cTxtFile
  LOCAL nAction
  LOCAL cExt
  LOCAL cTmpDir
  LOCAL cTmpFile
  LOCAL cInputPass
  LOCAL cOwnPass
  LOCAL cUserPass
  LOCAL cStdOut
  LOCAL cStdErr
  LOCAL nExitCode
  LOCAL cInfoFile
  LOCAL cSourceFile
  LOCAL cTargetFile
  LOCAL lOpenAtOnce

  IF Empty(cPDFtkName)
    RETURN NIL
  ENDIF

  cPdfFile := BooksWnd.DocTBox.VALUE
  cTxtFile := BooksWnd.TxtTBox.VALUE
  nAction  := BooksWnd.RadioRG.VALUE

  IF ! HB_FileExists(cPdfFile)
    MsgWin(cPdfFile + CRLF2 + LangStr(LS_NoFile))
    SendMessage(BooksWnd.MakeButton.HANDLE, 244 /*BM_SETSTYLE*/, 0 /*BS_PUSHBUTTON*/, 1)
    BooksWnd.DocTBox.SETFOCUS
    RETURN NIL
  ENDIF

  IF (nAction == 3) .and. (! HB_FileExists(cTxtFile))
    MsgWin(cTxtFile + CRLF2 + LangStr(LS_NoFile))
    SendMessage(BooksWnd.MakeButton.HANDLE, 244 /*BM_SETSTYLE*/, 0 /*BS_PUSHBUTTON*/, 1)
    BooksWnd.TxtTBox.SETFOCUS
    RETURN NIL
  ENDIF

  cExt    := HB_fNameExt(cPdfFile)
  cTmpDir := DirTmpCreate()

  BooksWnd.StatusLabel.VALUE := LangStr(LS_Wait) + ": " + LangStr(LS_PDFtkWorking)

  IF HB_StrIsUTF8(cPdfFile)
    cTmpFile := cTmpDir + "a" + cExt

    IF ! FileCopy(cPdfFile, cTmpFile)
      HB_DirRemoveAll(cTmpDir)
      BooksWnd.StatusLabel.VALUE := ""
      MsgWin(LangStr(LS_FileCopyError) + CRLF2 + cPdfFile + CRLF + "=>" + CRLF + cTmpFile)
      RETURN NIL
    ENDIF
  ELSE
    cTmpFile := cPdfFile
  ENDIF

  IF nAction == 3
    cInfoFile := PDFtk_BookmarksGetInfoFile(cTxtFile, cTmpDir)

    IF Empty(cInfoFile)
      HB_DirRemoveAll(cTmpDir)
      BooksWnd.StatusLabel.VALUE := ""
      MsgWin(cTxtFile + CRLF2 + LangStr(LS_NoBookmarks))
      RETURN NIL
    ENDIF
  ENDIF

  cSourceFile := cTmpDir + "b" + cExt
  cInputPass  := FileRecentGetPass(cPdfFile)
  cOwnPass    := If(Empty(BooksWnd.OwnPassTBox.VALUE), '', ' owner_pw "' + BooksWnd.OwnPassTBox.VALUE + '"')
  cUserPass   := If(Empty(BooksWnd.UserPassTBox.VALUE), '', ' user_pw "' + BooksWnd.UserPassTBox.VALUE + '"')

  DO WHILE .T.
    IF nAction == 1
      nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cTmpFile + '" input_pw "' + cInputPass + '" dump_data_utf8"', NIL, @cStdOut, @cStdErr, .T.)
    ELSEIF nAction == 2
      nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cTmpFile + '" input_pw "' + cInputPass + '" cat 1-end output "' + cSourceFile + '" allow AllFeatures' + cOwnPass + cUserPass, NIL, NIL, @cStdErr, .T.)
    ELSE
      nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cTmpFile + '" input_pw "' + cInputPass + '" update_info_utf8 "' + cInfoFile + '" output "' + cSourceFile + '" allow AllFeatures' + cOwnPass + cUserPass, NIL, NIL, @cStdErr, .T.)
    ENDIF

    IF PDFtk_PassRequired(nExitCode, @cStdErr)
      cInputPass := PDFtk_InputPassword(cPdfFile, cInputPass, ClientToScreenRow(BooksWnd.HANDLE, BooksWnd.DocTBox.ROW + BooksWnd.DocTBox.HEIGHT) + 3, ClientToScreenCol(BooksWnd.HANDLE, BooksWnd.DocTBox.COL))

      IF ! HB_IsString(cInputPass)
        BooksWnd.StatusLabel.VALUE := ""
        EXIT
      ENDIF
    ELSE
      IF nExitCode < 0
        BooksWnd.StatusLabel.VALUE := ""
        MsgWin(LangStr(LS_CantRunPDFtk), LangStr(LS_PDFtkError))
      ELSEIF nExitCode > 0
        BooksWnd.StatusLabel.VALUE := ""
        MsgWin(cPdfFile + CRLF + Replicate("-", 10) + CRLF + cStdErr, LangStr(LS_PDFtkError))
      ENDIF
      EXIT
    ENDIF
  ENDDO

  IF nExitCode == 0
    IF nAction == 1
      PDFtk_BookmarksSaveInTXT(cPdfFile, @cStdOut)
    ELSE
      BooksWnd.StatusLabel.VALUE := ""

      IF ! Empty(cTargetFile := PutFile({{"*" + cExt, "*" + cExt}}, NIL, HB_fNameDir(cPdfFile), .T., FileUniqueName(cPdfFile), cExt))

        IF FileCopy(cSourceFile, cTargetFile)
          lOpenAtOnce  := slOpenAtOnce
          slOpenAtOnce := .F.
          scFileDir    := HB_fNameDir(cTargetFile)

          Files_Refresh(HB_fNameNameExt(cTargetFile))

          slOpenAtOnce := lOpenAtOnce
        ELSE
          MsgWin(LangStr(LS_FileCopyError) + CRLF2 + cSourceFile + CRLF + "=>" + CRLF + cTargetFile)
        ENDIF
      ENDIF
    ENDIF

    IF ! Empty(cInputPass)
      FileRecentAdd(cPdfFile, NIL, cInputPass)
    ENDIF
  ENDIF

  HB_DirRemoveAll(cTmpDir)

RETURN NIL


FUNCTION PDFtk_BookmarksSaveInTXT(cPdfFile, /*@*/ cStdOut)
  LOCAL cBookmarks := ""
  LOCAL cTitle
  LOCAL nLevel
  LOCAL cExt
  LOCAL cTxtFile
  LOCAL n1, n2

  n1 := 1

  DO WHILE (n1 := HB_UTF8At("BookmarkBegin" + CRLF + "BookmarkTitle: ", cStdOut, n1)) > 0
    n1 += 30

    IF (n2 := HB_UTF8At(CRLF, cStdOut, n1)) == 0
      EXIT
    ENDIF

    cTitle := HB_UTF8SubStr(cStdOut, n1, n2 - n1)

    n1 := n2 + 2
    n2 := n1 + 15

    IF ! (HB_UTF8SubStr(cStdOut, n1, n2 - n1) == "BookmarkLevel: ")
      EXIT
    ENDIF

    n1 := n2

    IF (n2 := HB_UTF8At(CRLF, cStdOut, n1)) == 0
      EXIT
    ENDIF

    nLevel := Val(HB_UTF8SubStr(cStdOut, n1, n2 - n1))

    n1 := n2 + 2
    n2 := n1 + 20

    IF ! (HB_UTF8SubStr(cStdOut, n1, n2 - n1) == "BookmarkPageNumber: ")
      EXIT
    ENDIF

    n1 := n2

    IF (n2 := HB_UTF8At(CRLF, cStdOut, n1)) == 0
      EXIT
    ENDIF

    cBookmarks += Replicate(Chr(9), nLevel - 1) + cTitle + "/" + HB_UTF8SubStr(cStdOut, n1, n2 - n1) + CRLF

    n1 := n2 + 2
  ENDDO

  BooksWnd.StatusLabel.VALUE := ""

  IF Empty(cBookmarks)
    MsgWin(cPdfFile + CRLF2 + LangStr(LS_NoBookmarks))
  ELSE
    cExt     := ".txt"
    cTxtFile := PutFile({{"*" + cExt, "*" + cExt}}, NIL, HB_fNameDir(cPdfFile), .T., FileUniqueName(HB_fNameDir(cPdfFile) + HB_fNameName(cPdfFile) + cExt), cExt)

    IF ! Empty(cTxtFile)
      HB_MemoWrit(cTxtFile, UTF8_BOM + cBookmarks)
    ENDIF
  ENDIF

RETURN NIL


FUNCTION PDFtk_BookmarksGetInfoFile(cTxtFile, cTmpDir)
  LOCAL aLine := HB_aTokens(HB_MemoRead(cTxtFile), CRLF)
  LOCAL cText := ""
  LOCAL cInfoFile
  LOCAL cLine
  LOCAL cTitle
  LOCAL nLevel
  LOCAL cPage
  LOCAL n

  IF ! Empty(aLine) .and. HMG_IsUTF8WithBOM(aLine[1])
    aLine[1] := HMG_UTF8RemoveBOM(aLine[1])
  ENDIF

  FOR EACH cLine IN aLine
    cLine  := RTrim(cLine)
    nLevel := 1

    DO WHILE (HB_UTF8Peek(cLine, nLevel) == 9 /*TAB*/)
      ++nLevel
    ENDDO

    n := HB_UTF8RAt("/", cLine)

    cPage := HB_UTF8SubStr(cLine, n + 1)

    IF IsDigitString(cPage)
      cTitle := HB_UTF8SubStr(cLine, nLevel, n - nLevel)
    ELSE
      cPage  := "0"
      cTitle := HB_UTF8SubStr(cLine, nLevel)
    ENDIF

    IF ! Empty(cTitle)
      cText += "BookmarkBegin" + CRLF + "BookmarkTitle: " + cTitle + CRLF + "BookmarkLevel: " + HB_NtoS(nLevel) + CRLF + "BookmarkPageNumber: " + cPage + CRLF
    ENDIF
  NEXT

  IF ! Empty(cText)
    cInfoFile := cTmpDir + "a.txt"
    HB_MemoWrit(cInfoFile, UTF8_BOM + cText)
  ENDIF

RETURN cInfoFile


FUNCTION PDFtk_PageCount(cFileName, /*@*/ cPass)
  LOCAL nPages     := 0
  LOCAL cPDFtkName := PDFtk_ExeName()
  LOCAL cExt
  LOCAL cTmpDir
  LOCAL cTmpFile
  LOCAL cTmpFileName
  LOCAL cInputPass
  LOCAL cStdOut
  LOCAL cStdErr
  LOCAL nExitCode
  LOCAL nPos

  IF Empty(cPDFtkName)
    RETURN nPages
  ENDIF

  IF HB_StrIsUTF8(cFileName)
    cExt         := HB_fNameExt(cFileName)
    cTmpDir      := DirTmpCreate()
    cTmpFile     := "a"
    cTmpFileName := cTmpDir + cTmpFile + cExt

    IF ! FileCopy(cFileName, cTmpFileName)
      MsgWin(LangStr(LS_FileCopyError) + CRLF2 + cFileName + CRLF + "=>" + CRLF + cTmpFileName)
      HB_DirRemoveAll(cTmpDir)
      RETURN nPages
    ENDIF
  ELSE
    cTmpFileName := cFileName
  ENDIF

  cInputPass := cPass

  DO WHILE .T.
    //nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cTmpFileName + '" input_pw "' + cInputPass + '" dump_data_annots', NIL, @cStdOut, @cStdErr, .T.)
    nExitCode := HB_ProcessRun('"' + cPDFtkName + '" "' + cTmpFileName + '" input_pw "' + cInputPass + '" dump_data', NIL, @cStdOut, @cStdErr, .T.)

    IF PDFtk_PassRequired(nExitCode, @cStdErr)
      cInputPass := PDFtk_InputPassword(cFileName, cInputPass)

      IF ! HB_IsString(cInputPass)
        EXIT
      ENDIF
    ELSE
      IF nExitCode < 0
        MsgWin(cFileName + CRLF + Replicate("-", 10) + CRLF + LangStr(LS_CantRunPDFtk), LangStr(LS_PDFtkError))
      ELSEIF nExitCode > 0
        MsgWin(cFileName + CRLF + Replicate("-", 10) + CRLF + cStdErr, LangStr(LS_PDFtkError))
      ENDIF
      EXIT
    ENDIF
  ENDDO

  IF nExitCode == 0
    nPos := At("NumberOfPages: ", @cStdOut)

    IF nPos == 0
      MsgWin(cFileName, LangStr(LS_PDFtkError))
    ELSE
      nPages := Val(HB_UTF8SubStr(@cStdOut, nPos + 15, 6))
      cPass  := cInputPass
    ENDIF
  ENDIF

  HB_DirRemoveAll(cTmpDir)

RETURN nPages


FUNCTION PDFtk_PassRequired(nExitCode, /*@*/ cStdErr)

  IF (nExitCode == 1) .and. ("OWNER PASSWORD REQUIRED" $ cStdErr)
    RETURN .T.
  ENDIF

RETURN .F.


FUNCTION PDFtk_ExeName()
  LOCAL cPDFtk     := "PDFtk.exe"
  LOCAL cPDFtkName := If(Empty(scPDFtkDir), HB_DirBase(), DirSepAdd(TrueName(scPDFtkDir))) + cPDFtk

  IF ! HB_FileExists(cPDFtkName)
    MsgWin(cPDFtkName + CRLF2 + LangStr(LS_NoFile) + CRLF + LangStr(LS_SetPathTo) + " " + cPDFtk + ".")
    PDFviewOptions(2)
    RETURN ""
  ENDIF

RETURN cPDFtkName


FUNCTION PDFtk_PageRangesHelp(lMerge, nHwndTBox)
  LOCAL cRotate
  LOCAL cExample

  IF lMerge
    cRotate  := LangStr(LS_RotatePages) + CRLF + ;
                "< - " + LangStr(LS_Left,  .T.) + " (-90°)" + CRLF + ;
                "> - " + LangStr(LS_Right, .T.) + " (+90°)" + CRLF + ;
                "_ - " + LangStr(LS_Down,  .T.) + " (180°)" + CRLF2
    cExample := "2,4-6;10-20/;40-30\<,!9-!7,!3-z>"
  ELSE
    cRotate  := ""
    cExample := "2,4-6;10-20/,!9-!7,!3-z"
  ENDIF

  MsgWin(LangStr(LS_RangeCanBe) + CRLF + ;
                   LangStr(LS_RangeEmpty) + CRLF + ;
                   LangStr(LS_RangeSeparator) + CRLF2 + ;
                   "z - " + LangStr(LS_LastPageNum) + CRLF2 + ;
                   LangStr(LS_PageNumFromEnd) + CRLF + ;
                   "! - !1 = z, !z = 1, !3 = z-3" + CRLF2 + ;
                   LangStr(LS_EvenOddPages) + CRLF + ;
                   "/ - " + LangStr(LS_EvenNum) + CRLF + ;
                   "\ - " + LangStr(LS_OddNum) + CRLF2 + ;
                   cRotate + ;
                   LangStr(LS_Example) + cExample, ;
                 LangStr(LS_PageRanges), ;
                 NIL, ;
                 NIL, ;
                 GetWindowRow(nHwndTBox) + GetWindowHeight(nHwndTBox) + 3, ;
                 GetWindowCol(nHwndTBox))

RETURN NIL


FUNCTION PDFtk_InputPassword(cFile, cPassIn, nRow, nCol)
  LOCAL nHFocus := GetFocus()
  LOCAL cPassOut
  LOCAL nCAW
  LOCAL nEventID

  DEFINE WINDOW PassWnd;
    HEIGHT 97 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(LS_OwnerPassReq);
    MODAL;
    NOSIZE

    DEFINE LABEL FileLabel
      ROW    10
      COL    10
      HEIGHT 13
      VALUE  cFile
    END LABEL

    DEFINE TEXTBOX PassTBox
      ROW         33
      WIDTH       150
      HEIGHT      21
      VALUE       cPassIn
      MAXLENGTH   32
      DATATYPE    CHARACTER
      PASSWORD    (! slPassShow)
      ONENTER     If(IsWindowActive(PassWnd), ((cPassOut := PassWnd.PassTBox.VALUE), PassWnd.RELEASE), NIL)
      ONGOTFOCUS  SetDefPushButton(PassWnd.OK.HANDLE, .T.)
      ONLOSTFOCUS SetDefPushButton(PassWnd.OK.HANDLE, .F.)
    END TEXTBOX

    DEFINE CHECKBOX PassShowCBox
      ROW         38
      WIDTH       110
      HEIGHT      16
      VALUE       slPassShow
      CAPTION     LangStr(LS_ShowPass)
      ONCHANGE    ((slPassShow := ! slPassShow), SendMessage(PassWnd.PassTBox.HANDLE, 0x00CC /*EM_SETPASSWORDCHAR*/, If(slPassShow, 0, 0x25CF), 0), PassWnd.PassTBox.REDRAW)
      ONENTER     If(IsWindowActive(PassWnd), ((cPassOut := PassWnd.PassTBox.VALUE), PassWnd.RELEASE), NIL)
      ONGOTFOCUS  SetDefPushButton(PassWnd.OK.HANDLE, .T.)
      ONLOSTFOCUS SetDefPushButton(PassWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE BUTTON OK
      ROW     64
      WIDTH   70
      HEIGHT  23
      CAPTION LangStr(LS_OK)
      ACTION  ((cPassOut := PassWnd.PassTBox.VALUE), PassWnd.RELEASE)
    END BUTTON

    DEFINE BUTTON Cancel
      ROW     64
      WIDTH   70
      HEIGHT  23
      CAPTION LangStr(LS_Cancel)
      ACTION  PassWnd.RELEASE
    END BUTTON
  END WINDOW

  nCAW                     := Max(290, GetWindowTextWidth(PassWnd.FileLabel.HANDLE) + 20)
  PassWnd.FileLabel.WIDTH  := nCAW - 20
  PassWnd.PassTBox.COL     := Round((nCAW - 270) / 2, 0)
  PassWnd.PassShowCBox.COL := Round((nCAW - 270) / 2, 0) + 160
  PassWnd.OK.COL           := Round((nCAW - 150) / 2, 0)
  PassWnd.Cancel.COL       := Round((nCAW - 150) / 2, 0) + 80
  PassWnd.WIDTH            := nCAW + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;

  IF HB_IsNumeric(nRow) .and. HB_IsNumeric(nCol)
    PassWnd.ROW := nRow
    PassWnd.COL := nCol
  ELSE
    C_Center(PassWnd.HANDLE, GetActiveWindow())
  ENDIF

  SetDefPushButton(PassWnd.OK.HANDLE, .T.)

  nEventID := EventCreate({|| If(IsWindowActive(PassWnd) .and. (LoWord(EventWPARAM()) == IDCANCEL), PassWnd.RELEASE, NIL)}, PassWnd.HANDLE, 273 /*WM_COMMAND*/)

  ON KEY F1 OF PassWnd ACTION NIL

  PassWnd.ACTIVATE

  EventRemove(nEventID)
  SetFocus(nHFocus)

RETURN cPassOut


FUNCTION PDFviewOptions(nDir)
  LOCAL aLabel := {{NIL, NIL, NIL, 0, saFColor[FCOLOR_DIRT],     ""},                        ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_DIRB],     LangStr(LS_Directories)},   ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_DIRSELAT], ""},                        ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_DIRSELAB], LangStr(LS_SelDirPanelA)},  ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_DIRSELNT], ""},                        ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_DIRSELNB], LangStr(LS_SelDirPanelNA)}, ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_PDFT],     ""},                        ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_PDFB],     LangStr(LS_Files)},         ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_PDFSELAT], ""},                        ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_PDFSELAB], LangStr(LS_SelFilePanelA)}, ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_PDFSELNT], ""},                        ;
                   {NIL, NIL, NIL, 0, saFColor[FCOLOR_PDFSELNB], LangStr(LS_SelFilePanelNA)}}
  LOCAL aLang := LangStr()
  LOCAL nEventID
  LOCAL n

  DEFINE WINDOW OptionsWnd;
    WIDTH  600 + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;
    HEIGHT 380 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(LS_Options, .T.);
    MODAL;
    NOSIZE;
    ON INIT  StopControlEventProcedure("Files", "PDFviewWnd", .T.);
    ON PAINT Options_OnPaint(aLabel, ThisWindow.HANDLE)

    DEFINE FRAME GeneralFrame
      ROW     10
      COL     10
      WIDTH   300
      HEIGHT  360
      CAPTION LangStr(LS_General)
    END FRAME

    HMG_ChangeWindowStyle(OptionsWnd.GeneralFrame.HANDLE, 0x0300 /*BS_CENTER*/, NIL, .F., .F.)

    DEFINE LABEL LangLabel
      ROW    33
      COL    20
      HEIGHT 13
      VALUE  LangStr(LS_Language)
    END LABEL

    DEFINE COMBOBOX LangCombo
      ROW         30
      COL         0
      WIDTH       120
      HEIGHT      200
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END COMBOBOX

    DEFINE CHECKBOX SingleRunAppCBox
      ROW         71
      COL         20
      WIDTH       280
      HEIGHT      16
      CAPTION     LangStr(LS_NotRunAppTwice)
      VALUE       slSingleRunApp
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE CHECKBOX SingleOpenPDFCBox
      ROW         91
      COL         20
      WIDTH       280
      HEIGHT      16
      CAPTION     LangStr(LS_NotOpenPDFTwice)
      VALUE       slSingleOpenPDF
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE CHECKBOX OpenAtOnceCBox
      ROW         111
      COL         20
      WIDTH       280
      HEIGHT      16
      CAPTION     LangStr(LS_OpenAtOnce)
      VALUE       slOpenAtOnce
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE CHECKBOX SessionRestCBox
      ROW         131
      COL         20
      WIDTH       280
      HEIGHT      16
      CAPTION     LangStr(LS_RestSession)
      VALUE       slSessionRest
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE CHECKBOX EscExitCBox
      ROW         151
      COL         20
      WIDTH       280
      HEIGHT      16
      CAPTION     LangStr(LS_EscExit)
      VALUE       slEscExit
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE CHECKBOX TabGoToFileCBox
      ROW         171
      COL         20
      WIDTH       280
      HEIGHT      16
      CAPTION     LangStr(LS_TabGoToFile)
      VALUE       slTabGoToFile
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END CHECKBOX

    DEFINE LABEL TabNewLabel
      ROW    210
      COL    20
      HEIGHT 13
      VALUE  LangStr(LS_NewTabOpen)
    END LABEL

    DEFINE COMBOBOX TabNewCombo
      ROW         207
      COL         0
      WIDTH       110
      HEIGHT      200
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END COMBOBOX

    DEFINE LABEL TabsWidthLabel
      ROW    240
      COL    20
      HEIGHT 13
      VALUE  LangStr(LS_TabsWidth)
    END LABEL

    DEFINE SPINNER TabsWidthSpin
      ROW          237
      COL          0
      WIDTH        40
      HEIGHT       21
      RANGEMIN     0
      RANGEMAX     999
      VALUE        snTab_W
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END SPINNER

    DEFINE LABEL SumatraLabel
      ROW    278
      COL    20
      WIDTH  280
      HEIGHT 13
      VALUE  LangStr(LS_SumatraDir) + ":"
    END LABEL

    DEFINE TEXTBOX SumatraTBox
      ROW         293
      COL         20
      WIDTH       260
      HEIGHT      21
      DATATYPE    CHARACTER
      VALUE       scSumatraDir
      MAXLENGTH   240
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END TEXTBOX

    DEFINE BUTTON SumatraButton
      ROW        292
      COL        280
      WIDTH      20
      HEIGHT     23
      CAPTION    "..."
      ACTION     Options_BrowseForFolder(1)
      ONGOTFOCUS Options_LabelFrame(aLabel, 0)
    END BUTTON

    DEFINE LABEL PDFtkLabel
      ROW    324
      COL    20
      WIDTH  280
      HEIGHT 13
      VALUE  LangStr(LS_PDFtkDir) + ":"
    END LABEL

    DEFINE TEXTBOX PDFtkTBox
      ROW         339
      COL         20
      WIDTH       260
      HEIGHT      21
      DATATYPE    CHARACTER
      VALUE       scPDFtkDir
      MAXLENGTH   240
      ONGOTFOCUS  (SetDefPushButton(OptionsWnd.OK.HANDLE, .T.), Options_LabelFrame(aLabel, 0))
      ONLOSTFOCUS SetDefPushButton(OptionsWnd.OK.HANDLE, .F.)
    END TEXTBOX

    DEFINE BUTTON PDFtkButton
      ROW        338
      COL        280
      WIDTH      20
      HEIGHT     23
      CAPTION    "..."
      ACTION     Options_BrowseForFolder(2)
      ONGOTFOCUS Options_LabelFrame(aLabel, 0)
    END BUTTON

    DEFINE FRAME FilesFrame
      ROW     10
      COL     320
      WIDTH   270
      HEIGHT  315
      CAPTION LangStr(LS_ColorsFilesPanel)
    END FRAME

    HMG_ChangeWindowStyle(OptionsWnd.FilesFrame.HANDLE, 0x0300 /*BS_CENTER*/, NIL, .F., .F.)

    DEFINE LABEL TextLabel
      ROW       30
      COL       330
      WIDTH     30
      HEIGHT    13
      VALUE     LangStr(LS_Text, .T.)
    END LABEL

    DEFINE LABEL BackLabel
      ROW       30
      COL       370
      WIDTH     210
      HEIGHT    13
      VALUE     LangStr(LS_Background)
    END LABEL

    FOR n := 1 TO Len(aLabel) STEP 2
      aLabel[n]  [LABEL_NAME] := "Color" + HB_NtoS(n)
      aLabel[n+1][LABEL_NAME] := "Color" + HB_NtoS(n+1)

      DEFINE LABEL &(aLabel[n][LABEL_NAME])
        ROW       50 + 20 * (n - 1)
        COL       330
        WIDTH     30
        HEIGHT    20
        BACKCOLOR ColorArray(aLabel[n][LABEL_COLOR])
        VALUE     aLabel[n][LABEL_VALUE]
      END LABEL

      DEFINE LABEL &(aLabel[n+1][LABEL_NAME])
        ROW       50 + 20 * (n - 1)
        COL       370
        WIDTH     210
        HEIGHT    20
        FONTCOLOR ColorArray(aLabel[n]  [LABEL_COLOR])
        BACKCOLOR ColorArray(aLabel[n+1][LABEL_COLOR])
        ALIGNMENT CENTER
        VALUE     aLabel[n+1][LABEL_VALUE]
      END LABEL

      aLabel[n]  [LABEL_HWND] := GetProperty("OptionsWnd", aLabel[n]  [LABEL_NAME], "HANDLE")
      aLabel[n+1][LABEL_HWND] := GetProperty("OptionsWnd", aLabel[n+1][LABEL_NAME], "HANDLE")

      aLabel[n]  [LABEL_EVENT] := EventCreate({ || Options_LabelEventHandler(aLabel) }, aLabel[n]  [LABEL_HWND])
      aLabel[n+1][LABEL_EVENT] := EventCreate({ || Options_LabelEventHandler(aLabel) }, aLabel[n+1][LABEL_HWND])

      HMG_ChangeWindowStyle(aLabel[n]  [LABEL_HWND], 0x00810000 /*WS_BORDER|WS_TABSTOP*/,                NIL, .F., .T.)
      HMG_ChangeWindowStyle(aLabel[n+1][LABEL_HWND], 0x00810200 /*WS_BORDER|WS_TABSTOP|SS_CENTERIMAGE*/, NIL, .F., .T.)
    NEXT

    DEFINE BUTTON ResetButton
      ROW        290
      COL        410
      WIDTH      90
      HEIGHT     23
      CAPTION    LangStr(LS_Default)
      ACTION     Options_LabelDefaultColors(aLabel, ThisWindow.NAME)
      ONGOTFOCUS Options_LabelFrame(aLabel, 0)
    END BUTTON

    DEFINE BUTTON OK
      ROW        347
      COL        440
      WIDTH      70
      HEIGHT     23
      CAPTION    LangStr(LS_OK)
      ACTION     Options_Save(IDOK, aLang, aLabel)
      ONGOTFOCUS Options_LabelFrame(aLabel, 0)
    END BUTTON

    DEFINE BUTTON Cancel
      ROW        347
      COL        520
      WIDTH      70
      HEIGHT     23
      CAPTION    LangStr(LS_Cancel)
      ACTION     Options_Save(IDCANCEL)
      ONGOTFOCUS Options_LabelFrame(aLabel, 0)
    END BUTTON
  END WINDOW

  FOR n := 1 TO Len(aLang)
    OptionsWnd.LangCombo.AddItem(aLang[n][1] + " " + aLang[n][2])
  NEXT

  OptionsWnd.TabNewCombo.AddItem(LangStr(LS_BeforeCurrent))
  OptionsWnd.TabNewCombo.AddItem(LangStr(LS_AfterCurrent))
  OptionsWnd.TabNewCombo.AddItem(LangStr(LS_AtBeginning))
  OptionsWnd.TabNewCombo.AddItem(LangStr(LS_AtEnd))

  OptionsWnd.LangCombo.VALUE   := HB_aScan(aLang, {|a| a[3] == scLang})
  OptionsWnd.TabNewCombo.VALUE := snTabNew

  OptionsWnd.LangLabel.WIDTH := GetWindowTextWidth(OptionsWnd.LangLabel.HANDLE, NIL, .T.)
  OptionsWnd.LangCombo.COL   := OptionsWnd.LangLabel.COL + OptionsWnd.LangLabel.WIDTH + 3

  OptionsWnd.TabNewLabel.WIDTH := GetWindowTextWidth(OptionsWnd.TabNewLabel.HANDLE, NIL, .T.)
  OptionsWnd.TabNewCombo.COL   := OptionsWnd.TabNewLabel.COL + OptionsWnd.TabNewLabel.WIDTH + 3

  OptionsWnd.TabsWidthLabel.WIDTH := GetWindowTextWidth(OptionsWnd.TabsWidthLabel.HANDLE, NIL, .T.)
  OptionsWnd.TabsWidthSpin.COL    := OptionsWnd.TabsWidthLabel.COL + OptionsWnd.TabsWidthLabel.WIDTH + 3

  IF HB_IsNumeric(nDir)
    IF nDir == 1
      OptionsWnd.SumatraTBox.SETFOCUS
    ELSEIF nDir == 2
      OptionsWnd.PDFtkTBox.SETFOCUS
    ENDIF
  ENDIF

  nEventID := EventCreate({|| Options_Save(LoWord(EventWPARAM()), aLang, aLabel)}, OptionsWnd.HANDLE, 273 /*WM_COMMAND*/)

  ON KEY F1 OF OptionsWnd ACTION NIL

  OptionsWnd.CenterIn(PDFviewWnd)
  OptionsWnd.ACTIVATE

  EventRemove(nEventID)

  FOR n := 1 TO Len(aLabel)
    EventRemove(aLabel[n][LABEL_EVENT])
  NEXT

  StopControlEventProcedure("Files", "PDFviewWnd", .F.)
  Files_CellNavigationColor()

RETURN NIL


FUNCTION Options_OnPaint(aLabel, nHWnd)
  LOCAL nLabelDel := aScan(aLabel, { |a1| a1[LABEL_FRAME] == 2 })
  LOCAL nLabelSet := aScan(aLabel, { |a1| a1[LABEL_FRAME] == 1 })
  LOCAL aBTStru
  LOCAL nHDC
  LOCAL aRect

  IF nLabelDel > 0
    aLabel[nLabelDel][LABEL_FRAME] := 0
  ENDIF

  IF nLabelSet > 0
    nHDC  := BT_CreateDC(nHWnd, BT_HDC_INVALIDCLIENTAREA, @aBTStru)
    aRect := Array(4)

    GetControlRect(aLabel[nLabelSet][LABEL_HWND], aRect)
    BT_DrawRectangle(nHDC, aRect[2] - 2, aRect[1] - 2, aRect[3] - aRect[1] + 3, aRect[4] - aRect[2] + 3, ColorArray(GetSysColor(6 /*COLOR_WINDOWFRAME*/)), 1)
    BT_DeleteDC(aBTStru)
  ENDIF

RETURN NIL


FUNCTION Options_LabelEventHandler(aLabel)
  LOCAL nHWnd   := EventHWND()
  LOCAL nMsg    := EventMSG()
  LOCAL nWParam := EventWPARAM()

  SWITCH nMsg
    CASE WM_KEYDOWN
      IF nWParam == VK_TAB
        Options_LabelFrame(aLabel, GetNextDlgTabItem(GetParent(nHWnd), nHWnd, (GetKeyState(VK_SHIFT) < 0)))
      ELSEIF (nWParam == VK_RETURN) .or. (nWParam == VK_SPACE)
        Options_LabelColor(aLabel, nHWnd)
        RETURN 0
      ENDIF
      EXIT

    CASE WM_KEYUP
      IF nWParam == VK_TAB
        Options_LabelFrame(aLabel, nHWnd)
      ENDIF
      EXIT

    CASE WM_LBUTTONDOWN
      SetFocus(nHWnd)
      Options_LabelFrame(aLabel, nHWnd)
      Options_LabelColor(aLabel, nHWnd)
      EXIT

    CASE WM_RBUTTONDOWN
      SetFocus(nHWnd)
      Options_LabelFrame(aLabel, nHWnd)
      EXIT
  ENDSWITCH

RETURN NIL


FUNCTION Options_LabelFrame(aLabel, nHWnd)
  LOCAL nLabelDel := aScan(aLabel, { |a1| a1[LABEL_FRAME] == 1 })
  LOCAL nLabelSet := aScan(aLabel, { |a1| a1[LABEL_HWND] == nHWnd })
  LOCAL aRect

  IF nLabelDel != nLabelSet
    aRect := Array(4)

    IF nLabelDel > 0
      aLabel[nLabelDel][LABEL_FRAME] := 2

      GetControlRect(aLabel[nLabelDel][LABEL_HWND], aRect)
      aRect[1] -= 2
      aRect[2] -= 2
      aRect[3] += 2
      aRect[4] += 2
      InvalidateRect(OptionsWnd.HANDLE, aRect, .T.)
    ENDIF

    IF nLabelSet > 0
      aLabel[nLabelSet][LABEL_FRAME] := 1

      GetControlRect(aLabel[nLabelSet][LABEL_HWND], aRect)
      aRect[1] -= 2
      aRect[2] -= 2
      aRect[3] += 2
      aRect[4] += 2
      InvalidateRect(OptionsWnd.HANDLE, aRect, .F.)
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Options_LabelColor(aLabel, nHWnd)
  LOCAL nLabel := aScan(aLabel, { |a1| a1[LABEL_HWND] == nHWnd })
  LOCAL nRGB   := ChooseColor(NIL, aLabel[nLabel][LABEL_COLOR], NIL, .T.)
  LOCAL cForm

  IF nRGB >= 0
    aLabel[nLabel][LABEL_COLOR] := nRGB

    GetControlNameByHandle(nHWnd, NIL, @cForm)
    SetProperty(cForm, aLabel[nLabel][LABEL_NAME], "BACKCOLOR", ColorArray(nRGB))

    IF (nLabel % 2) == 1
      SetProperty(cForm, aLabel[nLabel+1][LABEL_NAME], "FONTCOLOR", ColorArray(nRGB))
    ENDIF
  ENDIF

RETURN NIL


FUNCTION Options_LabelDefaultColors(aLabel, cForm)
  LOCAL aFColor := Files_GetDefaultColors()
  LOCAL n

  FOR n := 1 TO Len(aLabel)
    aLabel[n][LABEL_COLOR] := aFColor[n]
  NEXT

  FOR n := 1 TO Len(aLabel) STEP 2
    SetProperty(cForm, aLabel[n]  [LABEL_NAME], "BACKCOLOR", ColorArray(aFColor[n]))
    SetProperty(cForm, aLabel[n+1][LABEL_NAME], "FONTCOLOR", ColorArray(aFColor[n]))
    SetProperty(cForm, aLabel[n+1][LABEL_NAME], "BACKCOLOR", ColorArray(aFColor[n+1]))
  NEXT

RETURN NIL


FUNCTION Options_BrowseForFolder(nDir)
  LOCAL cDir
  LOCAL nHWnd
  LOCAL nRow
  LOCAL nCol

  IF nDir == 1
    cDir  := DirSepAdd(TrueName(OptionsWnd.SumatraTBox.VALUE))
    nHWnd := OptionsWnd.SumatraTBox.HANDLE
    nRow  := OptionsWnd.SumatraTBox.ROW + OptionsWnd.SumatraTBox.HEIGHT
    nCol  := OptionsWnd.SumatraTBox.COL
  ELSE
    cDir  := DirSepAdd(TrueName(OptionsWnd.PDFtkTBox.VALUE))
    nHWnd := OptionsWnd.PDFtkTBox.HANDLE
    nRow  := OptionsWnd.PDFtkTBox.ROW + OptionsWnd.PDFtkTBox.HEIGHT
    nCol  := OptionsWnd.PDFtkTBox.COL
  ENDIF

  IF ! HB_DirExists(cDir)
    cDir := HB_DirBase()
  ENDIF

  ClientToScreen(OptionsWnd.HANDLE, @nCol, @nRow)

  cDir := BrowseForFolder(CRLF + LangStr(If(nDir == 1, LS_SelSumatraDir, LS_SelPDFtkDir)), HB_BitOr(BIF_NEWDIALOGSTYLE, BIF_NONEWFOLDERBUTTON), NIL, NIL, cDir, nRow + 3, nCol)

  IF ! Empty(cDir)
    HMG_EditControlSetSel(nHWnd, 0, -1)
    HMG_EditControlReplaceSel(nHWnd, .T., DirSepAdd(cDir))
  ENDIF

RETURN NIL


FUNCTION Options_Save(nCmd, aLang, aLabel)
  LOCAL cTabCaption
  LOCAL n

  IF nCmd != IDOK
    IF nCmd == IDCANCEL
      OptionsWnd.RELEASE
    ENDIF

    RETURN NIL
  ENDIF

  slSingleRunApp  := OptionsWnd.SingleRunAppCBox.VALUE
  slSingleOpenPDF := OptionsWnd.SingleOpenPDFCBox.VALUE
  slOpenAtOnce    := OptionsWnd.OpenAtOnceCBox.VALUE
  slSessionRest   := OptionsWnd.SessionRestCBox.VALUE
  slEscExit       := OptionsWnd.EscExitCBox.VALUE
  slTabGoToFile   := OptionsWnd.TabGoToFileCBox.VALUE
  snTabNew        := OptionsWnd.TabNewCombo.VALUE
  snTab_W         := OptionsWnd.TabsWidthSpin.VALUE
  scSumatraDir    := DirSepAdd(OptionsWnd.SumatraTBox.VALUE)
  scPDFtkDir      := DirSepAdd(OptionsWnd.PDFtkTBox.VALUE)

  FOR n := 1 TO Len(aLabel)
    saFColor[n] := aLabel[n][LABEL_COLOR]
  NEXT

  FOR n := 1 TO Len(saTab)
    cTabCaption := HB_fNameName(Sumatra_FileName(PanelName(saTab[n])))

    IF (snTab_W > 0) .and. (HMG_Len(cTabCaption) > snTab_W)
      cTabCaption := HB_UTF8Left(cTabCaption, snTab_W) + "..."
    ENDIF

    PDFviewWnd.Tabs.Caption(n) := cTabCaption
  NEXT

  SetLangInterface(aLang[OptionsWnd.LangCombo.VALUE][3])

  PDFview_SetOnKey(.T.) //for slEscExit update

  SettingsWrite(.F.)

  OptionsWnd.RELEASE

RETURN NIL


FUNCTION AboutPDFview()
  LOCAL aVersion := GetFileVersion(GetProgramFileName())

  DEFINE WINDOW AboutWnd;
    WIDTH  270 + GetSystemMetrics(7 /*SM_CXFIXEDFRAME*/) * 2;
    HEIGHT 261 + GetSystemMetrics(4 /*SM_CYCAPTION*/) + GetSystemMetrics(8 /*SM_CYFIXEDFRAME*/) * 2;
    TITLE  LangStr(LS_AboutPDFview, .T.);
    MODAL;
    NOSIZE

    DEFINE LABEL Label1
      ROW       10
      HEIGHT    32
      FONTNAME  "Times New Roman"
      FONTSIZE  22
      FONTBOLD  .T.
      VALUE     scProgName
    END LABEL

    DEFINE LABEL Label2
      ROW    25
      HEIGHT 13
      VALUE  "v." + HB_NtoS(aVersion[1]) + "-" + PadL(HB_NtoS(aVersion[2]), 2, "0") + "-" + PadL(HB_NtoS(aVersion[3]), 2, "0") + If(aVersion[4] == 0, "", "-" + HB_NtoS(aVersion[4])) + " (" + HB_NtoS(HB_Version(HB_VERSION_BITWIDTH)) + "-bit)"
    END LABEL

    DEFINE LABEL Label3
      ROW       50
      WIDTH     AboutWnd.CLIENTAREAWIDTH
      HEIGHT    13
      ALIGNMENT CENTER
      VALUE     LangStr(LS_PDFviewUsing)
    END LABEL

    DEFINE HYPERLINK Link1
      ROW        70
      HEIGHT     13
      HANDCURSOR .T.
      VALUE      "SumatraPDF"
    END HYPERLINK

    DEFINE HYPERLINK Link2
      ROW        90
      HEIGHT     13
      HANDCURSOR .T.
      VALUE      "PDFtk Server"
    END HYPERLINK

    DEFINE LABEL Label4
      ROW    120
      COL    -1
      WIDTH  AboutWnd.CLIENTAREAWIDTH + 2
      HEIGHT 80
      VALUE  CRLF + Space(14) + LangStr(LS_DevelopedIn)        + ;
             CRLF + Space(20) + _HMG_VERSION_NUMBER_           + ;
             CRLF + Space(20) + HB_Version(HB_VERSION_HARBOUR) + ;
             CRLF + Space(20) + HB_Version(HB_VERSION_COMPILER)
    END LABEL

    DEFINE LABEL Label5
      ROW       213
      WIDTH     AboutWnd.CLIENTAREAWIDTH
      HEIGHT    13
      ALIGNMENT CENTER
      VALUE     LangStr(LS_Author) + " Krzysztof Janicki (aka KDJ)"
    END LABEL

    DEFINE HYPERLINK Link3
      ROW        233
      HEIGHT     13
      HANDCURSOR .T.
      VALUE      LangStr(LS_SourceCode)
    END HYPERLINK

  END WINDOW

  HMG_ChangeWindowStyle(AboutWnd.Label4.HANDLE, 0x00800000 /*WS_BORDER*/, NIL, .F., .T.)

  AboutWnd.Label1.WIDTH := GetWindowTextWidth(AboutWnd.Label1.HANDLE)
  AboutWnd.Label2.WIDTH := GetWindowTextWidth(AboutWnd.Label2.HANDLE)
  AboutWnd.Label1.COL   := Int((AboutWnd.CLIENTAREAWIDTH - AboutWnd.Label1.WIDTH - AboutWnd.Label2.WIDTH - 10) / 2)
  AboutWnd.Label2.COL   := AboutWnd.Label1.COL + AboutWnd.Label1.WIDTH + 10

  AboutWnd.Link1.WIDTH := GetWindowTextWidth(AboutWnd.Link1.HANDLE)
  AboutWnd.Link1.COL   := Int((AboutWnd.CLIENTAREAWIDTH - AboutWnd.Link1.WIDTH) / 2)
  AboutWnd.Link2.WIDTH := GetWindowTextWidth(AboutWnd.Link2.HANDLE)
  AboutWnd.Link2.COL   := Int((AboutWnd.CLIENTAREAWIDTH - AboutWnd.Link2.WIDTH) / 2)
  AboutWnd.Link3.WIDTH := GetWindowTextWidth(AboutWnd.Link3.HANDLE)
  AboutWnd.Link3.COL   := Int((AboutWnd.CLIENTAREAWIDTH - AboutWnd.Link3.WIDTH) / 2)

  //bug in HMG, if protocol is "https" it opens "mailto"
  _HMG_SYSDATA[6][GetControlIndex("Link1", "AboutWnd")] := {|| ShellExecute(0, "open", "rundll32.exe", "url.dll, FileProtocolHandler " + "https://www.sumatrapdfreader.org", , 1 /*SW_SHOWNORMAL*/)}
  _HMG_SYSDATA[6][GetControlIndex("Link2", "AboutWnd")] := {|| ShellExecute(0, "open", "rundll32.exe", "url.dll, FileProtocolHandler " + "https://www.pdflabs.com/tools/pdftk-server", , 1 /*SW_SHOWNORMAL*/)}
  _HMG_SYSDATA[6][GetControlIndex("Link3", "AboutWnd")] := {|| ShellExecute(0, "open", "rundll32.exe", "url.dll, FileProtocolHandler " + "https://www.hmgforum.com/viewtopic.php?f=40&t=5112&p=61688#p61688", , 1 /*SW_SHOWNORMAL*/)}

  ON KEY F1 OF AboutWnd ACTION If(IsWindowActive(AboutWnd), AboutWnd.RELEASE, NIL)

  AboutWnd.CenterIn(PDFviewWnd)
  AboutWnd.ACTIVATE

RETURN NIL


       //MsgWin(cMsg, [cTitle], [acButton], [nDefButton], [nRow], [nCol]) --> nButton or zero
FUNCTION MsgWin(cMsg, cTitle, aButton, nDefButton, nRow, nCol)
  LOCAL nHFocus  := GetFocus()
  LOCAL nRetVal  := 0
  LOCAL nButtonW := 70
  LOCAL nButtonH := 23
  LOCAL nButtonC
  LOCAL nLabelW, nLabelH
  LOCAL nCAW
  LOCAL nButtons
  LOCAL nEventID
  LOCAL n

  HB_Default(@cTitle, scProgName)

  IF ! HB_IsArray(aButton)
    aButton := {LangStr(LS_OK)}
  ENDIF

  nButtons := Len(aButton)

  IF (! HB_IsNumeric(nDefButton)) .or. (nDefButton < 1) .or. (nDefButton > nButtons)
    nDefButton := 1
  ENDIF

  IF IsWindowVisible(GetMainFormHandle())
    DEFINE WINDOW MsgWnd;
      TITLE cTitle;
      MODAL;
      NOSIZE;
      ON RELEASE EventRemove(nEventID)
  ELSE
    DEFINE WINDOW MsgWnd;
      TITLE cTitle;
      CHILD;
      NOMINIMIZE;
      NOMAXIMIZE;
      NOSIZE;
      ON RELEASE EventRemove(nEventID)
  ENDIF

    DEFINE LABEL MsgText
      ROW   10
      VALUE cMsg
    END LABEL

    FOR n := 1 TO nButtons
      DEFINE BUTTON &("Button" + HB_NtoS(n))
        HEIGHT  nButtonH
        CAPTION aButton[n]
        ACTION  If(IsWindowActive(MsgWnd), (nRetVal := Val(Right(This.NAME, 1)), MsgWnd.RELEASE), NIL)
      END BUTTON
    NEXT
  END WINDOW

  FOR n := 1 TO nButtons
    nButtonW := Max(nButtonW, GetWindowTextWidth(GetProperty("MsgWnd", "Button" + HB_NtoS(n), "HANDLE"), NIL, .T.) + 10)
  NEXT

  nLabelW := GetWindowTextWidth(MsgWnd.MsgText.HANDLE)
  nLabelH := GetWindowTextHeight(MsgWnd.MsgText.HANDLE)

  nCAW := Max(Max(GetWindowTextWidth(MsgWnd.HANDLE) + GetSystemMetrics(49 /*SM_CXSMICON*/) + GetSystemMetrics(30 /*SM_CXSIZE*/) + 5, nLabelW + 20), nButtonW * nButtons + 10 * (nButtons + 1))
  nCAW := Max(100, nCAW)

  MsgWnd.WIDTH  := nCAW + (MsgWnd.WIDTH - MsgWnd.CLIENTAREAWIDTH)
  MsgWnd.HEIGHT := nLabelH + nButtonH + 30 + (MsgWnd.HEIGHT - MsgWnd.CLIENTAREAHEIGHT)

  MsgWnd.MsgText.COL    := Int((nCAW - nLabelW) / 2)
  MsgWnd.MsgText.WIDTH  := nLabelW
  MsgWnd.MsgText.HEIGHT := nLabelH

  nButtonC := Int((nCAW - (nButtonW * nButtons + 10 * (nButtons - 1))) / 2)

  FOR n := 1 TO nButtons
    SetProperty("MsgWnd", "BUtton" + HB_NtoS(n), "ROW",   nLabelH + 20)
    SetProperty("MsgWnd", "BUtton" + HB_NtoS(n), "COL",   nButtonC + (nButtonW + 10) * (n - 1))
    SetProperty("MsgWnd", "BUtton" + HB_NtoS(n), "WIDTH", nButtonW)
  NEXT

  IF HB_IsNumeric(nRow) .and. HB_IsNumeric(nCol)
    MsgWnd.ROW := nRow
    MsgWnd.COL := nCol
  ELSE
    C_Center(MsgWnd.HANDLE, GetActiveWindow())
  ENDIF

  IF MsgWnd.ROW < 0
    MsgWnd.ROW := 0
  ENDIF

  DoMethod("MsgWnd","BUtton" + HB_NtoS(nDefButton), "SETFOCUS")

  nEventID := EventCreate({|| If(IsWindowActive(MsgWnd) .and. (LoWord(EventWPARAM()) == IDCANCEL), PostMessage(MsgWnd.HANDLE, 16 /*WM_CLOSE*/, 0, 0), NIL)}, MsgWnd.HANDLE, 273 /*WM_COMMAND*/)

  ON KEY F1 OF MsgWnd ACTION NIL

  MsgWnd.ACTIVATE

  SetFocus(nHFocus)

RETURN nRetVal


FUNCTION MainEventHandler(nHWnd, nMsg, nWParam, nLParam)
  STATIC snHFocusMenu
  LOCAL  cPanel
  LOCAL  nHWndFrom
  LOCAL  nRow, nCol

  IF nHWnd == PDFviewWnd.HANDLE
    SWITCH nMsg
      CASE 36 /*WM_GETMINMAXINFO*/
        SetMinMaxTrackSize(nLParam, 550, 300)
        EXIT

      CASE 274 /*WM_SYSCOMMAND*/
        IF HB_BitAnd(nWParam, 0xFFF0) == 0xF100 /*SC_KEYMENU*/
          //for Win-10
          IF GetFocus() != PDFviewWnd.Files.HANDLE
            snHFocusMenu := GetFocus()
            PDFviewWnd.Files.SETFOCUS
            PostMessage(nHWnd, nMsg, nWParam, nLParam)
            RETURN 1
          ENDIF
          //

          IF GetMenu(nHWnd) == 0
            SetMenu(nHWnd, snHMenuMain)
          ELSEIF ! slMenuBar
            SetMenu(nHWnd, 0)
            RETURN 1
          ENDIF

          PDFviewWnd.PdfTimer.ENABLED := .F.
        ENDIF
        RETURN 0

      CASE 278 /*WM_INITMENU*/
        slMenuActive := .T.
        MenuCommandsEnable()
        PDFview_SetOnKey(.F.)
        RETURN 0

      CASE 530 /*WM_EXITMENULOOP*/
        slMenuActive := .F.
        PDFview_SetOnKey(.T.)

        //for Win-10
        IF IsWindowEnabled(snHFocusMenu)
          SetFocus(snHFocusMenu)
          snHFocusMenu := NIL
        ENDIF
        //

        IF ! slMenuBar
          SetMenu(nHWnd, 0)
        ENDIF

        PDFviewWnd.PdfTimer.ENABLED := .T.
        RETURN 0

      CASE 78 /*WM_NOTIFY*/
        nHWndFrom := GetHWNDFrom(nLParam)

        IF nHWndFrom == PDFviewWnd.Files.HANDLE
          SWITCH GetNotifyCode(nLParam)
            CASE -2 /*NM_CLICK*/
            CASE -3 /*NM_DBLCLK*/
              HMG_GetCursorPos(nHWnd, @nRow, @nCol)

              IF ListView_HitTest(nHWndFrom, nRow, nCol)[1] == 0
                RETURN 1
              ENDIF
              EXIT
          ENDSWITCH
        ENDIF
        EXIT

      CASE WM_LBUTTONDOWN
        IF slFilesPanel .and. (nWParam == MK_LBUTTON)
          HMG_GetCursorPos(nHWnd, @nRow, @nCol)

          IF nCol <= PDFviewWnd.Tabs.COL
            HMG_SetCursorPos(nHWnd, nRow, PDFviewWnd.FilesShow.COL + Int(PDFviewWnd.FilesShow.WIDTH / 2))
            HMG_MouseClearBuffer()
            SetCursorShape("CurResizeWE")
            SetCapture(nHWnd)
          ENDIF
        ENDIF
        EXIT

      CASE WM_LBUTTONUP
        IF nHWnd == GetCapture()
          ReleaseCapture()
          SetCursorShape(IDC_ARROW)
        ENDIF
        EXIT

      CASE WM_RBUTTONUP
        HMG_GetCursorPos(nHWnd, @nRow, @nCol)

        IF nCol >= PDFviewWnd.Tabs.COL
          Tabs_Menu(.T.)
        ENDIF
        RETURN 1

      CASE WM_LBUTTONDBLCLK
      CASE WM_MBUTTONDOWN
        HMG_GetCursorPos(nHWnd, @nRow, @nCol)

        IF nCol <= PDFviewWnd.Tabs.COL
          Files_Show()
        ELSE
          IF ! TabRestore()
            FileGetAndOpen(.T.)
          ENDIF
        ENDIF
        EXIT

      CASE WM_MOUSEMOVE
        HMG_GetCursorPos(nHWnd, @nRow, @nCol)

        IF slFilesPanel
          IF nWParam == 0
            IF nCol <= PDFviewWnd.Tabs.COL
              SetCursorShape("CurResizeWE")
            ENDIF
          ELSEIF (nWParam == MK_LBUTTON) .and. (nHWnd == GetCapture())
            cPanel := PanelName()
            nCol   -= Int(PDFviewWnd.FilesShow.WIDTH / 2)

            IF nCol < (PDFviewWnd.Files.COL + 100)
              nCol := PDFviewWnd.Files.COL + 100
            ELSEIF nCol > (PDFviewWnd.CLIENTAREAWIDTH - PDFviewWnd.FilesShow.WIDTH - 200)
              nCol := PDFviewWnd.CLIENTAREAWIDTH - PDFviewWnd.FilesShow.WIDTH - 200
            ENDIF

            snFiles_W := nCol - PDFviewWnd.Files.COL
            PDFviewWnd.Files.WIDTH := snFiles_W
            PDFviewWnd.Files.ColumnWIDTH(1) := snFiles_W - 4 - If(PDFviewWnd.Files.ITEMCOUNT > ListViewGetCountPerPage(PDFviewWnd.Files.HANDLE), GetVScrollBarWidth(), 0)

            PDFviewWnd.FilesShow.COL := nCol
            PDFviewWnd.Tabs.COL := nCol + PDFviewWnd.FilesShow.WIDTH

            SetProperty(cPanel, "COL", ClientToScreenCol(PDFviewWnd.HANDLE, nCol + PDFviewWnd.FilesShow.WIDTH))
            SetProperty(cPanel, "WIDTH", PDFviewWnd.CLIENTAREAWIDTH - nCol - PDFviewWnd.FilesShow.WIDTH)

            Sumatra_FrameAdjust(cPanel)
          ENDIF
        ENDIF
        EXIT

      CASE 32 /*WM_SETCURSOR*/
        IF nWParam == PDFviewWnd.FilesShow.HANDLE
          SetCursorShape("HMG_FINGER")
          RETURN 1
        ENDIF

        IF (nWParam == nHWnd) .and. (! slFilesPanel)
          HMG_GetCursorPos(nHWnd, @nRow, @nCol)

          IF (nRow >= 0) .and. (nCol >= 0) .and. (nCol <= PDFviewWnd.Tabs.COL)
            SetCursorShape("CurArrowNE")
            RETURN 1
          ENDIF
        ENDIF
        EXIT

      CASE 123 /*WM_CONTEXTMENU*/
        IF slFilesPanel .and. (nWParam == PDFviewWnd.Files.HANDLE)
          Files_CellNavigationColor()
          Files_Menu(HiWord(nLParam), LoWord(nLParam))
        ENDIF
        EXIT

      CASE 74 /*WM_COPYDATA*/
        IF GetCopyDataAction(nLParam) == 1
          SessionOpen(2, HB_aTokens(GetCopyDataString(nLParam), Chr(9)))
        ENDIF
        EXIT

      CASE 0x8000 /*WM_APP*/
        SetFocus(nLParam)
        EXIT
    ENDSWITCH

  ELSEIF nHWnd == GetFormHandle(PanelName())
    SWITCH nMsg
      CASE WM_RBUTTONUP
        Tabs_Menu(.T.)
        RETURN 1

      CASE WM_LBUTTONDBLCLK
      CASE WM_MBUTTONDOWN
        IF ! TabRestore()
          FileGetAndOpen(.T.)
        ENDIF
        EXIT

      CASE 74 /*WM_COPYDATA*/
        IF GetCopyDataAction(nLParam) == 0x4C5255 /*URL*/
          ShellExecute(0, "open", "rundll32.exe", "url.dll, FileProtocolHandler " + GetCopyDataString(nLParam, .T.), NIL, 1 /*SW_SHOWNORMAL*/)
        ENDIF
        EXIT
    ENDSWITCH

  ELSEIF IsWindowDefined(RenameFileWnd) .and. (nHWnd == RenameFileWnd.HANDLE)
    IF (nMsg == 273 /*WM_COMMAND*/) .and. (LoWord(nWParam) == IDCANCEL)
      RenameFileWnd.RELEASE
    ENDIF

  ELSEIF IsWindowDefined(InputPageWnd) .and. (nHWnd == InputPageWnd.HANDLE)
    IF (nMsg == 273 /*WM_COMMAND*/) .and. (LoWord(nWParam) == IDCANCEL)
      InputPageWnd.RELEASE
    ENDIF

  ELSEIF IsWindowDefined(RecentWnd) .and. (nHWnd == RecentWnd.HANDLE)
    SWITCH nMsg
      CASE 36 /*WM_GETMINMAXINFO*/
        SetMinMaxTrackSize(nLParam, 380, 250)
        EXIT

      CASE 278 /*WM_INITMENU*/
        slMenuActive := .T.
        RETURN 0

      CASE 530 /*WM_EXITMENULOOP*/
        slMenuActive := .F.
        RETURN 0

      CASE 123 /*WM_CONTEXTMENU*/
        IF nWParam == RecentWnd.Files.HANDLE
          Recent_FilesMenu(HiWord(nLParam), LoWord(nLParam))
        ELSEIF nWParam == RecentWnd.OpenMenu.HANDLE
          Recent_OpenMenu()
        ELSEIF nWParam == RecentWnd.RemoveMenu.HANDLE
          Recent_RemoveMenu()
        ENDIF
        EXIT

      CASE 78 /*WM_NOTIFY*/
        IF GetHWNDFrom(nLParam) == RecentWnd.Files.HANDLE
          SWITCH GetNotifyCode(nLParam)
            CASE -2 /*NM_CLICK*/
            CASE -5 /*NM_RCLICK*/
            CASE -6 /*NM_RDBLCLK*/
              IF (RecentWnd.Files.VALUE == 0) .and. (RecentWnd.Files.CELLROWFOCUSED > 0)
                RecentWnd.Files.VALUE := RecentWnd.Files.CELLROWFOCUSED
              ENDIF
              EXIT
            CASE -3 /*NM_DBLCLK*/
              IF (RecentWnd.Files.VALUE == 0) .and. (RecentWnd.Files.CELLROWFOCUSED > 0)
                RecentWnd.Files.VALUE := RecentWnd.Files.CELLROWFOCUSED
              ELSEIF (RecentWnd.Files.VALUE > 0)
                Recent_FileOpen(If(GetKeyState(VK_CONTROL) < 0, -1, 0), If(GetKeyState(VK_SHIFT) < 0, 0, -1))
              ENDIF
              RETURN 1
          ENDSWITCH
        ENDIF
        EXIT

      CASE 273 /*WM_COMMAND*/
        IF LoWord(nWParam) == IDCANCEL
          RecentWnd.RELEASE
        ENDIF
        EXIT
    ENDSWITCH

  ELSEIF IsWindowDefined(TranslateWnd) .and. (nHWnd == TranslateWnd.HANDLE)
    IF (nMsg == 36 /*WM_GETMINMAXINFO*/)
      SetMinMaxTrackSize(nLParam, 458, 150)
    ELSEIF (nMsg == 273 /*WM_COMMAND*/) .and. (LoWord(nWParam) == IDCANCEL)
      TranslateWnd.RELEASE
    ENDIF

  ELSEIF IsWindowDefined(MergeWnd) .and. (nHWnd == MergeWnd.HANDLE)
    SWITCH nMsg
      CASE 36 /*WM_GETMINMAXINFO*/
        SetMinMaxTrackSize(nLParam, 470, 355)
        EXIT

      CASE 278 /*WM_INITMENU*/
        slMenuActive := .T.
        RETURN 0

      CASE 530 /*WM_EXITMENULOOP*/
        slMenuActive := .F.
        RETURN 0

      CASE 78 /*WM_NOTIFY*/
        IF GetHWNDFrom(nLParam) == MergeWnd.Files.HANDLE
          SWITCH GetNotifyCode(nLParam)
            CASE -2 /*NM_CLICK*/
            CASE -5 /*NM_RCLICK*/
            CASE -6 /*NM_RDBLCLK*/
              IF (MergeWnd.Files.VALUE == 0) .and. (MergeWnd.Files.CELLROWFOCUSED > 0)
                MergeWnd.Files.VALUE := MergeWnd.Files.CELLROWFOCUSED
              ENDIF
              EXIT
            CASE -3 /*NM_DBLCLK*/
              IF (MergeWnd.Files.VALUE == 0) .and. (MergeWnd.Files.CELLROWFOCUSED > 0)
                MergeWnd.Files.VALUE := MergeWnd.Files.CELLROWFOCUSED
              ELSEIF (MergeWnd.Files.VALUE > 0)
                MergeWnd.RangesTBox.SETFOCUS
              ENDIF
              RETURN 1
          ENDSWITCH
        ENDIF
        EXIT

      CASE 123 /*WM_CONTEXTMENU*/
        IF nWParam == MergeWnd.Files.HANDLE
          PdfMerge(HiWord(nLParam), LoWord(nLParam))
        ENDIF
        EXIT

      CASE 273 /*WM_COMMAND*/
        IF (LoWord(nWParam) == IDCANCEL)
          MergeWnd.RELEASE
        ENDIF
        EXIT
    ENDSWITCH

  ELSEIF IsWindowDefined(SplitWnd) .and. (nHWnd == SplitWnd.HANDLE)
    IF (nMsg == 273 /*WM_COMMAND*/) .and. (LoWord(nWParam) == IDCANCEL)
      SplitWnd.RELEASE
    ENDIF

  ELSEIF IsWindowDefined(BooksWnd) .and. (nHWnd == BooksWnd.HANDLE)
    IF (nMsg == 273 /*WM_COMMAND*/) .and. (LoWord(nWParam) == IDCANCEL)
      BooksWnd.RELEASE
    ENDIF

  ELSEIF IsWindowDefined(AboutWnd) .and. (nHWnd == AboutWnd.HANDLE)
    IF (nMsg == 273 /*WM_COMMAND*/) .and. (LoWord(nWParam) == IDCANCEL)
      AboutWnd.RELEASE
    ENDIF
  ENDIF

RETURN NIL


FUNCTION GetWindowTextWidth(nHWnd, cText, lNoPrefix)
  LOCAL nW     := 0
  LOCAL nHDC   := GetDC(nHWnd)
  LOCAL nHFont := GetWindowFont(nHWnd)
  LOCAL aText
  LOCAL n

  IF ! HB_IsString(cText)
    cText := GetWindowText(nHWnd)
  ENDIF

  IF lNoPrefix == .T.
    cText := HB_UTF8StrTran(cText, "&", "", 1, 1)
  ENDIF

  aText := HB_aTokens(cText, .T. /*lEOL*/)

  FOR n := 1 TO Len(aText)
    nW := Max(nW, GetTextWidth(nHDC, aText[n], nHFont))
  NEXT

  ReleaseDC(nHWnd, nHDC)

RETURN nW


FUNCTION GetWindowTextHeight(nHWnd, cText)
  LOCAL nHDC := GetDC(nHWnd)
  LOCAL nH

  IF ! HB_IsString(cText)
    cText := GetWindowText(nHWnd)
  ENDIF

  nH := GetTextHeight(nHDC, cText, GetWindowFont(nHWnd)) * HB_TokenCount(cText, .T. /*lEOL*/)

  ReleaseDC(nHWnd, nHDC)

RETURN nH


FUNCTION GetControlRect(nHWndControl, aRect)
  LOCAL nHWndParent := GetParent(nHWndControl)

  GetWindowRect(nHWndControl, aRect)
  ScreenToClient(nHWndParent, @aRect[1], @aRect[2])
  ScreenToClient(nHWndParent, @aRect[3], @aRect[4])

RETURN NIL


FUNCTION SetDefPushButton(nHWnd, lSet)

  IF lSet
    PostMessage(nHWnd, 244 /*BM_SETSTYLE*/, 1 /*BS_DEFPUSHBUTTON*/, 1)
  ELSE
    SendMessage(nHWnd, 244 /*BM_SETSTYLE*/, 0 /*BS_PUSHBUTTON*/, 1)
  ENDIF

RETURN NIL


FUNCTION ChangeWindowMessageFilter(nHWnd, nMsg, nAction)
  LOCAL nMajorVer := WinMajorVersionNumber()
  LOCAL nRetVal

  IF nMajorVer >= 6
    IF (nMajorVer == 6) .and. (WinMinorVersionNumber() == 0)
      nRetVal := HMG_CallDLL("User32", NIL, "ChangeWindowMessageFilter", nMsg, nAction)
    ELSE
      nRetVal := HMG_CallDLL("User32", NIL, "ChangeWindowMessageFilterEx", nHWnd, nMsg, nAction, 0)
    ENDIF
  ENDIF

RETURN nRetVal


FUNCTION IsDigitString(cStr)
  LOCAL nLen := HMG_Len(cStr)
  LOCAL n

  IF nLen == 0
    RETURN .F.
  ENDIF

  FOR n := 1 TO nLen
    IF ! IsDigit(HB_UTF8SubStr(cStr, n, 1))
      RETURN .F.
    ENDIF
  NEXT

RETURN .T.


FUNCTION ColorArray(nRGB)

RETURN {GetRed(nRGB), GetGreen(nRGB), GetBlue(nRGB)}


FUNCTION DirSepAdd(cDir)

  IF (! Empty(cDir)) .and. (! (HB_UTF8Right(cDir, 1) == "\"))
    cDir += "\"
  ENDIF

RETURN cDir


FUNCTION DirSepDel(cDir)

  IF HB_UTF8Right(cDir, 1) == "\"
    cDir := HB_StrShrink(cDir)
  ENDIF

RETURN cDir


FUNCTION DirParent(cDir)

  cDir := DirSepDel(cDir)

RETURN HB_UTF8Left(cDir, HB_UTF8RAt("\", cDir))


FUNCTION DirTmpCreate()
  LOCAL cTmpDir := GetTempDir()
  LOCAL cName   := HB_fNameName(GetProgramFileName())
  LOCAL nCount  := 0

  HB_DirBuild(cTmpDir)

  DO WHILE HB_fNameExists(cTmpDir + cName + "_" + HB_NtoS(nCount))
    ++nCount
  ENDDO

  HB_DirCreate(cTmpDir += cName + "_" + HB_NtoS(nCount) + "\")

RETURN cTmpDir


FUNCTION FileUniqueName(cFileName)
  LOCAL cUnique := cFileName
  LOCAL cDir    := HB_fNameDir(cFileName)
  LOCAL cFile   := HB_fNameName(cFileName)
  LOCAL cExt    := HB_fNameExt(cFileName)
  LOCAL nCount  := 1

  DO WHILE HB_fNameExists(cUnique)
    cUnique := cDir + cFile + "(" + HB_NtoS(nCount) + ")" + cExt
    ++nCount
  ENDDO

RETURN cUnique


FUNCTION FileCopy(cSourceFile, cTargetFile)

  HB_fSetAttr(cTargetFile, HB_FA_NORMAL)

RETURN (HB_fCopy(cSourceFile, cTargetFile) == 0)


FUNCTION FileNameValid(cName, /*@*/ nPos1, /*@*/ nPos2)
  LOCAL nLen := HB_UTF8Len(cName)
  LOCAL cReserved
  LOCAL aReserved
  LOCAL cName1
  LOCAL k, n

  //check trailing spaces and dots
  n := nLen
  DO WHILE (n > 0) .and. (HB_UTF8SubStr(cName, n, 1) $ " .")
    --n
  ENDDO

  IF n < nLen
    nPos1 := n + 1
    nPos2 := nLen
    RETURN .F.
  ENDIF

  //check reserved characters
  cReserved := ""
  FOR n := 0 TO 31
    cReserved += Chr(n)
  NEXT
  cReserved += '<>:"/\|?*'

  FOR k := 1 TO nLen
    n := k
    DO WHILE (n <= nLen) .and. (HB_UTF8SubStr(cName, n, 1) $ cReserved)
      ++n
    ENDDO

    IF n > k
      nPos1 := k
      nPos2 := n - 1
      RETURN .F.
    ENDIF
  NEXT

  //check reserved names
  aReserved := {"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"}
  cName1    := HB_TokenGet(cName, 1, ".")

  IF HB_aScan(aReserved, { |c| HMG_StrCmp(c, cName1, .F.) == 0 }) > 0
    nPos1 := 1
    nPos2 := HB_UTF8Len(cName1)
    RETURN .F.
  ENDIF

RETURN .T.


FUNCTION IsProgramRunning()
  LOCAL cCurProcName := HMG_Upper(GetProgramFileName())
  LOCAL nCurProcID   := GetCurrentProcessId()
  LOCAL aProcID      := EnumProcessesID()
  LOCAL nPID
  LOCAL aHWnd
  LOCAL nWinPID
  LOCAL nHMainWnd
  LOCAL cFiles
  LOCAL n

  FOR n := 1 TO Len(aProcID)
    IF (HMG_Upper(GetProcessFullName(aProcID[n])) == cCurProcName) .and. (aProcID[n] != nCurProcID)
      nPID := aProcID[n]
      EXIT
    ENDIF
  NEXT

  IF HB_IsNumeric(nPID)
    aHWnd := EnumWindows()

    FOR n := 1 TO Len(aHWnd)
      //IF (HMG_Upper(HB_UTF8Left(GetClassName(aHWnd[n]), 13)) == "_HMG_PDFVIEWWND_")
      IF IsWindowVisible(aHWnd[n]) .and. (! Empty(GetWindowText(aHWnd[n])))
        GetWindowThreadProcessId(aHWnd[n], NIL, @nWinPID)

        IF nWinPID == nPID
          nHMainWnd := aHWnd[n]
          EXIT
        ENDIF
      ENDIF
    NEXT

    IF HB_IsNumeric(nHMainWnd)
      IF IsMinimized(nHMainWnd)
        Restore(nHMainWnd)
      ELSE
        SetForegroundWindow(nHMainWnd)
      ENDIF

      IF HB_ArgC() > 0
        cFiles := scDirStart + Chr(9)

        FOR n := 1 TO HB_ArgC()
          cFiles += HB_ArgV(n) + If(n == HB_ArgC(), "", Chr(9))
        NEXT

        Send_WM_COPYDATA(nHMainWnd, 1, cFiles)
      ENDIF
    ELSE
      MsgWin(LangStr(LS_AppRunning))
    ENDIF
  ENDIF

RETURN HB_IsNumeric(nPID)


FUNCTION NumToHex(nNum, nDigits)

RETURN "0x" + HB_NumToHex(nNum, nDigits)


FUNCTION HexToNum(cHex)

  IF Left(cHex, 2) == "0x"
    cHex := SubStr(cHex, 3)
  ENDIF

RETURN HB_HexToNum(cHex)


FUNCTION SettingsRead()
  LOCAL aLine
  LOCAL cLine
  LOCAL cValue
  LOCAL aFile
  LOCAL nPos
  LOCAL nPosS
  LOCAL nPosF
  LOCAL n

  scProgName   := "PDFview"
  saTab        := {}
  saTabClosed  := {}
  saPanel      := {}
  slMenuActive := .F.

  saSession := {}
  saRecent  := {}

  slPDFview_Max    := .F.
  snPDFview_R      := 100
  snPDFview_C      := 100
  snPDFview_W      := 650
  snPDFview_H      := 450
  snFiles_W        := 150
  slPassShow       := .F.
  scFileDir        := HB_CWD()
  scFileLast       := ""
  snRecent_W       := 380
  snRecent_H       := 250
  slRecentNames    := .F.
  snRecentAmount   := 99
  snTranslate_W    := 458
  snTranslate_H    := 150
  scTranslateLang1 := ""
  scTranslateLang2 := ""
  snMerge_W        := 470
  snMerge_H        := 355
  slMergeNames     := .F.
  snZoom           := 0
  slMenuBar        := .T.
  slStatusBar      := .T.
  slFilesPanel     := .T.
  slToolBar        := .F.
  slBookmarks      := .T.
  scLang           := "en"
  slSingleRunApp   := .T.
  slSingleOpenPDF  := .F.
  slOpenAtOnce     := .F.
  slSessionRest    := .F.
  slEscExit        := .F.
  slTabGoToFile    := .F.
  snTabNew         := 4
  snTab_W          := 0
  scSumatraDir     := ".\SumatraPDF"
  scPDFtkDir       := ".\PDFtk"
  saFColor         := Files_GetDefaultColors()

  aLine := HB_aTokens(HB_MemoRead(HB_fNameExtSet(GetProcessFullName(), "ini")), CRLF)

  IF ! Empty(aLine) .and. HMG_IsUTF8WithBOM(aLine[1])
    aLine[1] := HMG_UTF8RemoveBOM(aLine[1])
  ENDIF

  FOR EACH cLine IN aLine
    cLine := AllTrim(cLine)
    nPos  := HB_UAt("=", cLine)

    IF nPos > 0
      cValue := HB_UTF8SubStr(cLine, nPos + 1)

      SWITCH HB_UTF8Left(cLine, nPos - 1)
        CASE "PDFview_Max"    ; slPDFview_Max             := (cValue == "T")  ; EXIT
        CASE "PDFview_R"      ; snPDFview_R               := Val(cValue)      ; EXIT
        CASE "PDFview_C"      ; snPDFview_C               := Val(cValue)      ; EXIT
        CASE "PDFview_W"      ; snPDFview_W               := Val(cValue)      ; EXIT
        CASE "PDFview_H"      ; snPDFview_H               := Val(cValue)      ; EXIT
        CASE "Files_W"        ; snFiles_W                 := Val(cValue)      ; EXIT
        CASE "PassShow"       ; slPassShow                := (cValue == "T")  ; EXIT
        CASE "FileDir"        ; scFileDir                 := cValue           ; EXIT
        CASE "FileLast"       ; scFileLast                := cValue           ; EXIT
        CASE "Recent_W"       ; snRecent_W                := Val(cValue)      ; EXIT
        CASE "Recent_H"       ; snRecent_H                := Val(cValue)      ; EXIT
        CASE "RecentNames"    ; slRecentNames             := (cValue == "T")  ; EXIT
        CASE "RecentAmount"   ; snRecentAmount            := Val(cValue)      ; EXIT
        CASE "Translate_W"    ; snTranslate_W             := Val(cValue)      ; EXIT
        CASE "Translate_H"    ; snTranslate_H             := Val(cValue)      ; EXIT
        CASE "TranslateLang1" ; scTranslateLang1          := cValue           ; EXIT
        CASE "TranslateLang2" ; scTranslateLang2          := cValue           ; EXIT
        CASE "Merge_W"        ; snMerge_W                 := Val(cValue)      ; EXIT
        CASE "Merge_H"        ; snMerge_H                 := Val(cValue)      ; EXIT
        CASE "MergeNames"     ; slMergeNames              := (cValue == "T")  ; EXIT
        CASE "Zoom"           ; snZoom                    := Val(cValue)      ; EXIT
        CASE "MenuBar"        ; slMenuBar                 := (cValue == "T")  ; EXIT
        CASE "StatusBar"      ; slStatusBar               := (cValue == "T")  ; EXIT
        CASE "FilesPanel"     ; slFilesPanel              := (cValue == "T")  ; EXIT
        CASE "ToolBar"        ; slToolBar                 := (cValue == "T")  ; EXIT
        CASE "Bookmarks"      ; slBookmarks               := (cValue == "T")  ; EXIT
        CASE "Lang"           ; scLang                    := cValue           ; EXIT
        CASE "SingleRunApp"   ; slSingleRunApp            := (cValue == "T")  ; EXIT
        CASE "SingleOpenPDF"  ; slSingleOpenPDF           := (cValue == "T")  ; EXIT
        CASE "OpenAtOnce"     ; slOpenAtOnce              := (cValue == "T")  ; EXIT
        CASE "RestSession"    ; slSessionRest             := (cValue == "T")  ; EXIT
        CASE "EscExit"        ; slEscExit                 := (cValue == "T")  ; EXIT
        CASE "TabGoToFile"    ; slTabGoToFile             := (cValue == "T")  ; EXIT
        CASE "TabNew"         ; snTabNew                  := Val(cValue)      ; EXIT
        CASE "Tab_W"          ; snTab_W                   := Val(cValue)      ; EXIT
        CASE "SumatraDir"     ; scSumatraDir              := cValue           ; EXIT
        CASE "PDFtkDir"       ; scPDFtkDir                := cValue           ; EXIT
        CASE "FColor1"        ; saFColor[FCOLOR_DIRT]     := HexToNum(cValue) ; EXIT
        CASE "FColor2"        ; saFColor[FCOLOR_DIRB]     := HexToNum(cValue) ; EXIT
        CASE "FColor3"        ; saFColor[FCOLOR_DIRSELAT] := HexToNum(cValue) ; EXIT
        CASE "FColor4"        ; saFColor[FCOLOR_DIRSELAB] := HexToNum(cValue) ; EXIT
        CASE "FColor5"        ; saFColor[FCOLOR_DIRSELNT] := HexToNum(cValue) ; EXIT
        CASE "FColor6"        ; saFColor[FCOLOR_DIRSELNB] := HexToNum(cValue) ; EXIT
        CASE "FColor7"        ; saFColor[FCOLOR_PDFT]     := HexToNum(cValue) ; EXIT
        CASE "FColor8"        ; saFColor[FCOLOR_PDFB]     := HexToNum(cValue) ; EXIT
        CASE "FColor9"        ; saFColor[FCOLOR_PDFSELAT] := HexToNum(cValue) ; EXIT
        CASE "FColor10"       ; saFColor[FCOLOR_PDFSELAB] := HexToNum(cValue) ; EXIT
        CASE "FColor11"       ; saFColor[FCOLOR_PDFSELNT] := HexToNum(cValue) ; EXIT
        CASE "FColor12"       ; saFColor[FCOLOR_PDFSELNB] := HexToNum(cValue) ; EXIT
      ENDSWITCH
    ENDIF
  NEXT

  IF snPDFview_W < 550
    snPDFview_W := 550
  ENDIF

  IF snPDFview_H < 300
    snPDFview_H := 300
  ENDIF

  IF snFiles_W < 100
    snFiles_W := 100
  ENDIF

  IF snRecent_W < 380
    snRecent_W := 380
  ENDIF

  IF snRecent_H < 250
    snRecent_H := 250
  ENDIF

  IF snTranslate_W < 458
    snTranslate_W := 458
  ENDIF

  IF snTranslate_H < 150
    snTranslate_H := 150
  ENDIF

  IF snMerge_W < 470
    snMerge_W := 470
  ENDIF

  IF snMerge_H < 355
    snMerge_H := 355
  ENDIF

  IF (snTabNew < 1) .or. (snTabNew > 4)
    snTabNew := 4
  ENDIF

  IF snTab_W < 0
    snTab_W := 0
  ENDIF

  IF ! Empty(scFileDir)
    IF (VolSerial(HB_UTF8Left(scFileDir, 3)) == -1) .or. (! HB_DirExists(scFileDir))
      scFileDir := HB_CWD()
    ELSE
      scFileDir := DirSepAdd(scFileDir)
    ENDIF
  ENDIF

  IF HB_aScan(LangStr(), {|aLang| aLang[3] == scLang}) == 0
    scLang := "en"
  ENDIF

  scSumatraDir := DirSepAdd(scSumatraDir)
  scPDFtkDir   := DirSepAdd(scPDFtkDir)

  scDirStart := HB_CWD(HB_DirBase())

  aLine := HB_aTokens(HB_MemoRead(HB_fNameExtSet(GetProcessFullName(), "recent")), CRLF)

  IF ! Empty(aLine) .and. HMG_IsUTF8WithBOM(aLine[1])
    aLine[1] := HMG_UTF8RemoveBOM(aLine[1])
  ENDIF

  nPosS := HB_aScan(aLine, "<session>", NIL, NIL, .T.)
  nPosF := HB_aScan(aLine, "<files>", NIL, NIL, .T.)

  IF nPosS > 0
    nPos := If(nPosS > nPosF, Len(aLine), nPosF - 1)

    FOR n := (nPosS + 1) TO nPos
      IF ! Empty(aLine[n])
        aFile := HB_aTokens(aLine[n], Chr(9))
        aAdd(saSession, {aFile[RECENTF_NAME], If(Len(aFile) > 1, Val(aFile[RECENTF_PAGE]), 1)})
      ENDIF
    NEXT
  ENDIF

  IF nPosF > 0
    nPos := If(nPosF > nPosS, Len(aLine), nPosS - 1)

    FOR n := (nPosF + 1) TO nPos
      IF ! Empty(aLine[n])
        aFile := HB_aTokens(aLine[n], Chr(9))
        aAdd(saRecent, {aFile[RECENTF_NAME], If(Len(aFile) > 1, Val(aFile[RECENTF_PAGE]), 1), If(Len(aFile) > 2, aFile[RECENTF_PASS], "")})
      ENDIF
    NEXT
  ENDIF

RETURN NIL


FUNCTION SettingsWrite(lRecent)
  LOCAL aWndPos := GetWindowNormalPos(PDFviewWnd.HANDLE)
  LOCAL cText
  LOCAL nPanel
  LOCAL cPanel
  LOCAL nPage
  LOCAL cFile
  LOCAL aFile
  LOCAL n

  SumatraGetSettings()

  IF lRecent
    cText := UTF8_BOM + "<session>" + CRLF

    IF ! saPanel[saTab[PDFviewWnd.Tabs.VALUE]]
      cText += "tab" + Chr(9) + HB_NtoS(PDFviewWnd.Tabs.VALUE) + CRLF

      FOR EACH nPanel IN saTab
        cPanel := PanelName(nPanel)
        cFile  := Sumatra_FileName(cPanel)
        nPage  := Sumatra_PageNumber(cPanel)

        IF ! Empty(cFile)
          cText += cFile + Chr(9) + HB_NtoS(nPage) + CRLF

          IF nPage > 0
            FileRecentAdd(cFile, nPage)
          ENDIF
        ENDIF

        Sumatra_FileClose(cPanel, .F.)
      NEXT
    ENDIF

    cText += "<files>" + CRLF

    FOR EACH aFile IN saRecent
      cText += aFile[RECENTF_NAME] + Chr(9) + HB_NtoS(aFile[RECENTF_PAGE]) + Chr(9) + aFile[RECENTF_PASS] + CRLF
    NEXT

    HB_MemoWrit(HB_fNameExtSet(GetProcessFullName(), "recent"), cText)
  ENDIF

  cText := UTF8_BOM + ;
           "PDFview_Max="    + If(PDFviewWnd.ISMAXIMIZED, "T", "F") + CRLF + ;
           "PDFview_R="      + HB_NtoS(aWndPos[2]) + CRLF + ;
           "PDFview_C="      + HB_NtoS(aWndPos[1]) + CRLF + ;
           "PDFview_W="      + HB_NtoS(aWndPos[3] - aWndPos[1]) + CRLF + ;
           "PDFview_H="      + HB_NtoS(aWndPos[4] - aWndPos[2]) + CRLF + ;
           "Files_W="        + HB_NtoS(snFiles_W) + CRLF + ;
           "PassShow="       + If(slPassShow, "T", "F") + CRLF + ;
           "FileDir="        + scFileDir + CRLF + ;
           "FileLast="       + PDFviewWnd.Files.CellEx(PDFviewWnd.Files.VALUE[1], F_NAME) + CRLF + ;
           "Recent_W="       + HB_NtoS(snRecent_W) + CRLF + ;
           "Recent_H="       + HB_NtoS(snRecent_H) + CRLF + ;
           "RecentNames="    + If(slRecentNames, "T", "F") + CRLF + ;
           "RecentAmount="   + HB_NtoS(snRecentAmount) + CRLF + ;
           "Translate_W="    + HB_NtoS(snTranslate_W) + CRLF + ;
           "Translate_H="    + HB_NtoS(snTranslate_H) + CRLF + ;
           "TranslateLang1=" + scTranslateLang1 + CRLF + ;
           "TranslateLang2=" + scTranslateLang2 + CRLF + ;
           "Merge_W="        + HB_NtoS(snMerge_W) + CRLF + ;
           "Merge_H="        + HB_NtoS(snMerge_H) + CRLF + ;
           "MergeNames="     + If(slMergeNames, "T", "F") + CRLF + ;
           "Zoom="           + HB_NtoS(snZoom) + CRLF + ;
           "MenuBar="        + If(slMenuBar, "T", "F") + CRLF + ;
           "StatusBar="      + If(slStatusBar, "T", "F") + CRLF + ;
           "FilesPanel="     + If(slFilesPanel, "T", "F") + CRLF + ;
           "ToolBar="        + If(slToolBar, "T", "F") + CRLF + ;
           "Bookmarks="      + If(slBookmarks, "T", "F") + CRLF + ;
           "Lang="           + scLang + CRLF + ;
           "SingleRunApp="   + If(slSingleRunApp, "T", "F") + CRLF + ;
           "SingleOpenPDF="  + If(slSingleOpenPDF, "T", "F") + CRLF + ;
           "OpenAtOnce="     + If(slOpenAtOnce, "T", "F") + CRLF + ;
           "RestSession="    + If(slSessionRest, "T", "F") + CRLF + ;
           "EscExit="        + If(slEscExit, "T", "F") + CRLF + ;
           "TabGoToFile="    + If(slTabGoToFile, "T", "F") + CRLF + ;
           "TabNew="         + HB_NtoS(snTabNew) + CRLF + ;
           "Tab_W="          + HB_NtoS(snTab_W) + CRLF + ;
           "SumatraDir="     + scSumatraDir + CRLF + ;
           "PDFtkDir="       + scPDFtkDir + CRLF

  FOR n := 1 TO Len(saFColor)
    cText += "FColor" + HB_NtoS(n) + "=" + NumToHex(saFColor[n], 6) + CRLF
  NEXT

  HB_MemoWrit(HB_fNameExtSet(GetProcessFullName(), "ini"), cText)

RETURN NIL


FUNCTION LangStr(nStr, lNoPrefix)
  LOCAL cText

  IF ! HB_IsNumeric(nStr)
    RETURN { ;
             {"English", "",          "en"}, ;
             {"Polish",  "(Polski)",  "pl"}, ;
             {"Russian", "(Русский)", "ru"}  ;
           }
  ENDIF

  cText := ""

  SWITCH scLang
    CASE "pl"
      SWITCH nStr
        CASE LS_File             ; cText := "&Plik"                                                      ; EXIT
        CASE LS_OpenInNewTab     ; cText := "&Otwórz w nowej karcie"                                     ; EXIT
        CASE LS_OpenInCurTab     ; cText := "Otwórz w &bieżącej karcie"                                  ; EXIT
        CASE LS_OpenPageInNewTab ; cText := "Otwórz na stronie w &nowej karcie"                          ; EXIT
        CASE LS_OpenPageInCurTab ; cText := "Otwórz na stronie w bieżącej &karcie"                       ; EXIT
        CASE LS_OpenFromDir      ; cText := "Otwórz z &katalogu"                                         ; EXIT
        CASE LS_PrevPDF          ; cText := "Poprz&edni PDF"                                             ; EXIT
        CASE LS_NextPDF          ; cText := "&Następny PDF"                                              ; EXIT
        CASE LS_FirstPDF         ; cText := "&Pierwszy PDF"                                              ; EXIT
        CASE LS_LastPDF          ; cText := "&Ostatni PDF"                                               ; EXIT
        CASE LS_OpenSession      ; cText := "Otwórz ostatnią &sesję"                                     ; EXIT
        CASE LS_RecentFiles      ; cText := "Ostatnio otwarte &pliki"                                    ; EXIT
        CASE LS_Rename           ; cText := "Zmień &nazwę"                                               ; EXIT
        CASE LS_Delete           ; cText := "&Usuń"                                                      ; EXIT
        CASE LS_Properties       ; cText := "&Właściwości"                                               ; EXIT
        CASE LS_GoToSubDir       ; cText := "Przejdź do podkatalogu"                                     ; EXIT
        CASE LS_GoToParentDir    ; cText := "Przejdź do katalogu nadrzędnego"                            ; EXIT
        CASE LS_ChooseDir        ; cText := "&Wybierz katalog"                                           ; EXIT
        CASE LS_RefreshList      ; cText := "Odśwież &listę"                                             ; EXIT
        CASE LS_Exit             ; cText := "&Zakończ"                                                   ; EXIT
        CASE LS_Document         ; cText := "&Dokument"                                                  ; EXIT
        CASE LS_Documents        ; cText := "Dokumenty"                                                  ; EXIT
        CASE LS_SaveAs           ; cText := "Zapi&sz jako"                                               ; EXIT
        CASE LS_Print            ; cText := "&Drukuj"                                                    ; EXIT
        CASE LS_PrintFile        ; cText := "Drukuj plik"                                                ; EXIT
        CASE LS_SelectAllInDoc   ; cText := "Z&aznacz wszystko w dokumencie"                             ; EXIT
        CASE LS_TranslateSel     ; cText := "&Tłumacz zaznaczony text"                                   ; EXIT
        CASE LS_MoveTab          ; cText := "Przesuń &kartę"                                             ; EXIT
        CASE LS_Left             ; cText := "W &lewo"                                                    ; EXIT
        CASE LS_Right            ; cText := "W &prawo"                                                   ; EXIT
        CASE LS_Up               ; cText := "W &górę"                                                    ; EXIT
        CASE LS_Down             ; cText := "W &dół"                                                     ; EXIT
        CASE LS_Beginning        ; cText := "N&a początek"                                               ; EXIT
        CASE LS_End              ; cText := "Na &koniec"                                                 ; EXIT
        CASE LS_CurrDoc          ; cText := "&Bieżący dokument (kartę)"                                  ; EXIT
        CASE LS_DupDoc           ; cText := "&Duplikaty bieżącego dokumentu"                             ; EXIT
        CASE LS_AllDup           ; cText := "Wszystkie duplikaty"                                        ; EXIT
        CASE LS_AllInactive      ; cText := "Wszystkie nieaktywne"                                       ; EXIT
        CASE LS_AllDoc           ; cText := "Wszystkie dokumenty"                                        ; EXIT
        CASE LS_RestoreLastTab   ; cText := "Przywróć &ostatnio zamkniętą kartę"                         ; EXIT
        CASE LS_NewDocument      ; cText := "&Nowy dokument"                                             ; EXIT
        CASE LS_ChooseDoc        ; cText := "Wybierz dokument/&menu kart"                                ; EXIT
        CASE LS_GoToFile         ; cText := "&Przejdź do pliku"                                          ; EXIT
        CASE LS_Tools            ; cText := "&Narzędzia"                                                 ; EXIT
        CASE LS_MergeSplitRotate ; cText := "&Scal/Podziel/Obróć"                                        ; EXIT
        CASE LS_SplitIntoPages   ; cText := "&Podziel ne pojedyncze strony"                              ; EXIT
        CASE LS_Page             ; cText := "&Strona"                                                    ; EXIT
        CASE LS_GoTo             ; cText := "Przejdź &do"                                                ; EXIT
        CASE LS_Prev             ; cText := "Poprz&ednia"                                                ; EXIT
        CASE LS_Next             ; cText := "&Następna"                                                  ; EXIT
        CASE LS_First            ; cText := "&Pierwsza"                                                  ; EXIT
        CASE LS_Last             ; cText := "&Ostatnia"                                                  ; EXIT
        CASE LS_Find             ; cText := "&Znajdź"                                                    ; EXIT
        CASE LS_Text             ; cText := "&Tekst"                                                     ; EXIT
        CASE LS_PrevOccur        ; cText := "&Poprzednie wystąpienie"                                    ; EXIT
        CASE LS_NextOccur        ; cText := "&Następne wystąpienie"                                      ; EXIT
        CASE LS_Zoom             ; cText := "&Rozmiar"                                                   ; EXIT
        CASE LS_SizeDown         ; cText := "&Zmniejsz"                                                  ; EXIT
        CASE LS_SizeUp           ; cText := "&Powiększ"                                                  ; EXIT
        CASE LS_ZoomFactor       ; cText := "&Współczynnik powiększenia"                                 ; EXIT
        CASE LS_FitPage          ; cText := "&Dopasuj do strony"                                         ; EXIT
        CASE LS_ActualSize       ; cText := "&Rozmiar rzeczywisty"                                       ; EXIT
        CASE LS_FitWidth         ; cText := "Dopasuj do &szerokości"                                     ; EXIT
        CASE LS_Rotate           ; cText := "&Obrót"                                                     ; EXIT
        CASE LS_View             ; cText := "&Widok"                                                     ; EXIT
        CASE LS_MenuBar          ; cText := "Pasek &menu"                                                ; EXIT
        CASE LS_StatusBar        ; cText := "Pasek &stanu"                                               ; EXIT
        CASE LS_FilesPanel       ; cText := "Panel &plików"                                              ; EXIT
        CASE LS_ToolBar          ; cText := "Pasek &narzędzi PDF"                                        ; EXIT
        CASE LS_Bookmarks        ; cText := "&Zakładki PDF"                                              ; EXIT
        CASE LS_Show             ; cText := "&Pokaż"                                                     ; EXIT
        CASE LS_ExpandAll        ; cText := "&Rozwiń wszystkie"                                          ; EXIT
        CASE LS_CollapseAll      ; cText := "&Zwiń wszystkie"                                            ; EXIT
        CASE LS_Settings         ; cText := "&Ustawienia"                                                ; EXIT
        CASE LS_Options          ; cText := "&Opcje"                                                     ; EXIT
        CASE LS_General          ; cText := "Ogólne"                                                     ; EXIT
        CASE LS_Language         ; cText := "&Język:"                                                    ; EXIT
        CASE LS_NotRunAppTwice   ; cText := "Nie uruchamiaj PDF&view dwukrotnie"                         ; EXIT
        CASE LS_NotOpenPDFTwice  ; cText := "Nie otwieraj pliku PDF &dwukrotnie"                         ; EXIT
        CASE LS_OpenAtOnce       ; cText := "&Otwieraj PDF od razu (panel plików)"                       ; EXIT
        CASE LS_RestSession      ; cText := "Przywróć ostatnią sesję &na starcie"                        ; EXIT
        CASE LS_EscExit          ; cText := "&Esc - kończy program"                                      ; EXIT
        CASE LS_TabGoToFile      ; cText := "&Zmieniając kartę, przejdź do pliku w panelu plików"        ; EXIT
        CASE LS_NewTabOpen       ; cText := "Nową &kartę otwieraj:"                                      ; EXIT
        CASE LS_BeforeCurrent    ; cText := "Przed bieżącą"                                              ; EXIT
        CASE LS_AfterCurrent     ; cText := "Za bieżącą"                                                 ; EXIT
        CASE LS_AtBeginning      ; cText := "Na początku"                                                ; EXIT
        CASE LS_AtEnd            ; cText := "Na końcu"                                                   ; EXIT
        CASE LS_TabsWidth        ; cText := "Szarokośc kart &w znakach, (0 - bez limitu):"               ; EXIT
        CASE LS_SumatraDir       ; cText := "Katalog &SumatraPDF.exe"                                    ; EXIT
        CASE LS_PDFtkDir         ; cText := "Katalog &PDFtk.exe"                                         ; EXIT
        CASE LS_ColorsFilesPanel ; cText := "Kolory w panelu plików"                                     ; EXIT
        CASE LS_Background       ; cText := "Tło"                                                        ; EXIT
        CASE LS_Directories      ; cText := "Katalogi"                                                   ; EXIT
        CASE LS_SelDirPanelA     ; cText := "Wybrany katalog - panel aktywny"                            ; EXIT
        CASE LS_SelDirPanelNA    ; cText := "Wybrany katalog - panel nieaktywny"                         ; EXIT
        CASE LS_Files            ; cText := "Pliki"                                                      ; EXIT
        CASE LS_SelFilePanelA    ; cText := "Wybrany plik - panel aktywny"                               ; EXIT
        CASE LS_SelFilePanelNA   ; cText := "Wybrany plik - panel nieaktywny"                            ; EXIT
        CASE LS_Default          ; cText := "Domyślne"                                                   ; EXIT
        CASE LS_AboutPDFview     ; cText := "O programie &PDFview"                                       ; EXIT
        CASE LS_AboutSumatra     ; cText := "O programie &SumatraPDF"                                    ; EXIT
        CASE LS_AppRunning       ; cText := "Program już jest uruchomiony!"                              ; EXIT
        CASE LS_Drive            ; cText := "Dysk"                                                       ; EXIT
        CASE LS_NoDisk           ; cText := "Dysk jest niedostępny!"                                     ; EXIT
        CASE LS_NoFile           ; cText := "Plik nie istnieje!"                                         ; EXIT
        CASE LS_InvalidVersion   ; cText := "Nieodpowiednia wersja SumatraPDF!"                          ; EXIT
        CASE LS_UseVersion       ; cText := "Użyj wersji 3.1.2 lub 3.2"                                  ; EXIT
        CASE LS_SetPathTo        ; cText := "Ustaw ścieżkę do:"                                          ; EXIT
        CASE LS_ListRefresh      ; cText := "Lista zostanie odświeżona."                                 ; EXIT
        CASE LS_Path             ; cText := "Ścieżka"                                                    ; EXIT
        CASE LS_Name             ; cText := "Nazwa"                                                      ; EXIT
        CASE LS_NewName          ; cText := "Nowa nazwa"                                                 ; EXIT
        CASE LS_IncorrectName    ; cText := "Nieprawidłowa nazwa!"                                       ; EXIT
        CASE LS_RenameDir        ; cText := "Zmień nazwę katalogu"                                       ; EXIT
        CASE LS_DeleteDir        ; cText := "Usuń katalog"                                               ; EXIT
        CASE LS_RenameFile       ; cText := "Zmień nazwę pliku"                                          ; EXIT
        CASE LS_DeleteFile       ; cText := "Usuń plik"                                                  ; EXIT
        CASE LS_CantRename       ; cText := "Nie można zmienić nazwy!"                                   ; EXIT
        CASE LS_CantDelete       ; cText := "Nie można skasować!"                                        ; EXIT
        CASE LS_DirInUse         ; cText := "Katalog jest aktualnie używany."                            ; EXIT
        CASE LS_FileInUse        ; cText := "Plik jest aktualnie używany."                               ; EXIT
        CASE LS_DirExists        ; cText := "Istnieje już katalog o podanej nazwie."                     ; EXIT
        CASE LS_FileExists       ; cText := "Istnieje już plik o podanej nazwie."                        ; EXIT
        CASE LS_DirNotEmpty      ; cText := "Katalog nie jest pusty."                                    ; EXIT
        CASE LS_DeleteAllContent ; cText := "Czy usunąć całą zawartość"                                  ; EXIT
        CASE LS_CantDeleteAll    ; cText := "Nie udało się usunąć niektórych plików/podkatalogów!"       ; EXIT
        CASE LS_OpenFilePage     ; cText := "Otwórz plik na stronie"                                     ; EXIT
        CASE LS_PageNum          ; cText := "Numer strony:"                                              ; EXIT
        CASE LS_SelSumatraDir    ; cText := "Wybierz katalog SumatraPDF:"                                ; EXIT
        CASE LS_SelPDFtkDir      ; cText := "Wybierz katalog PDFtk:"                                     ; EXIT
        CASE LS_OnlyNames        ; cText := "Tylko &nazwy"                                               ; EXIT
        CASE LS_FilesAmount      ; cText := "Liczba &plików:"                                            ; EXIT
        CASE LS_Remove           ; cText := "&Usuń"                                                      ; EXIT
        CASE LS_RemoveNonExist   ; cText := "Usuń &nieistniejące"                                        ; EXIT
        CASE LS_RemoveAll        ; cText := "Usuń &wszystko"                                             ; EXIT
        CASE LS_GoogleTranslator ; cText := "Tłumacz Google"                                             ; EXIT
        CASE LS_Translate        ; cText := "Przetłumacz"                                                ; EXIT
        CASE LS_TranslateError   ; cText := "Wystąpił błąd, nie można przetłumaczyć!"                    ; EXIT
        CASE LS_OutputDir        ; cText := "Katalog docelowy:"                                          ; EXIT
        CASE LS_TargetFiles      ; cText := "Pliki docelowe:"                                            ; EXIT
        CASE LS_PageRanges       ; cText := "Zakresy stron"                                              ; EXIT
        CASE LS_RangeCanBe       ; cText := "Zakres może być jedną stroną lub OdStrony-DoStrony."        ; EXIT
        CASE LS_RangeEmpty       ; cText := "Pusty zakres oznacza wszystkie strony dokumentu."           ; EXIT
        CASE LS_RangeSeparator   ; cText := "Separatorem zakresów jest przecinek lub średnik."           ; EXIT
        CASE LS_LastPageNum      ; cText := "numer ostatniej strony"                                     ; EXIT
        CASE LS_PageNumFromEnd   ; cText := "Numer strony od końca (użyj przed numerem strony):"         ; EXIT
        CASE LS_EvenOddPages     ; cText := "Strony parzyste/nieparzyste (użyj na końcu zakresu):"       ; EXIT
        CASE LS_EvenNum          ; cText := "parzyste"                                                   ; EXIT
        CASE LS_OddNum           ; cText := "nieparzyste"                                                ; EXIT
        CASE LS_RotatePages      ; cText := "Obróć strony w zakresie (użyj za zakresem):"                ; EXIT
        CASE LS_Example          ; cText := "Przykład:"                                                  ; EXIT
        CASE LS_SaveBooks        ; cText := "Zapisz zakładki z dokumentu w pliku tekstowym"              ; EXIT
        CASE LS_RemoveBooks      ; cText := "Usuń zakładki z dokumentu"                                  ; EXIT
        CASE LS_InsertBooks      ; cText := "Wstaw zakładki do dokumentu z poniższego pliku tekstowego:" ; EXIT
        CASE LS_PassProtect      ; cText := "Ochrona hasłem dokumentu docelowego"                        ; EXIT
        CASE LS_OwnerPass        ; cText := "Hasło właściciela"                                          ; EXIT
        CASE LS_UserPass         ; cText := "Hasło użytkownika:"                                         ; EXIT
        CASE LS_OwnerPassReq     ; cText := "Wymagane hasło właściciela"                                 ; EXIT
        CASE LS_ShowPass         ; cText := "Pokazuj hasła"                                              ; EXIT
        CASE LS_TotalPages       ; cText := "Liczba stron w dokumencie docelowym:"                       ; EXIT
        CASE LS_AllOpenedDocs    ; cText := "Wszystkie otwarte dokumenty"                                ; EXIT
        CASE LS_OtherDocs        ; cText := "Inne dokumenty"                                             ; EXIT
        CASE LS_Wait             ; cText := "Czekaj"                                                     ; EXIT
        CASE LS_Done             ; cText := "Gotowe!"                                                    ; EXIT
        CASE LS_PDFtkWorking     ; cText := "PDFtk pracuje"                                              ; EXIT
        CASE LS_CopyTarget       ; cText := "kopiowanie plików docelowych"                               ; EXIT
        CASE LS_RangesError      ; cText := "Błąd w zakresach stron!"                                    ; EXIT
        CASE LS_NoBookmarks      ; cText := "Nie ma zakładek w tym pliku!"                               ; EXIT
        CASE LS_CantRunPDFtk     ; cText := "Nie można uruchomić PDFtk.exe!"                             ; EXIT
        CASE LS_PDFtkError       ; cText := "Błąd PDFtk"                                                 ; EXIT
        CASE LS_FileOverwrite    ; cText := "Plik już istnieje. Czy nadpisać go?"                        ; EXIT
        CASE LS_FileCopyError    ; cText := "Błąd kopiowania pliku!"                                     ; EXIT
        CASE LS_PDFviewUsing     ; cText := "Podgląd, podział i łączenie PDF'ów za pomocą:"              ; EXIT
        CASE LS_DevelopedIn      ; cText := "Opracowany w:"                                              ; EXIT
        CASE LS_Author           ; cText := "Autor:"                                                     ; EXIT
        CASE LS_SourceCode       ; cText := "Kod źródłowy"                                               ; EXIT
        CASE LS_Open             ; cText := "&Otwórz"                                                    ; EXIT
        CASE LS_Add              ; cText := "D&odaj"                                                     ; EXIT
        CASE LS_AddAbove         ; cText := "Dodaj powyżej"                                              ; EXIT
        CASE LS_Duplicate        ; cText := "Powiel"                                                     ; EXIT
        CASE LS_EditRanges       ; cText := "Edytuj zakresy"                                             ; EXIT
        CASE LS_Make             ; cText := "&Wykonaj"                                                   ; EXIT
        CASE LS_Close            ; cText := "&Zamknij"                                                   ; EXIT
        CASE LS_OK               ; cText := "&OK"                                                        ; EXIT
        CASE LS_Cancel           ; cText := "&Anuluj"                                                    ; EXIT
        CASE LS_Yes              ; cText := "&Tak"                                                       ; EXIT
        CASE LS_YesForAll        ; cText := "Tak na &wszystkie"                                          ; EXIT
        CASE LS_Repeat           ; cText := "Powtó&rz"                                                   ; EXIT
        CASE LS_Skip             ; cText := "&Pomiń"                                                     ; EXIT

        CASE LS_Afrikaans     ; cText := "Afrykanerski"        ; EXIT
        CASE LS_Arabic        ; cText := "Arabski"             ; EXIT
        CASE LS_Azerbaijani   ; cText := "Azerski"             ; EXIT
        CASE LS_Belarusian    ; cText := "Białoruski"          ; EXIT
        CASE LS_Bulgarian     ; cText := "Bułgarski"           ; EXIT
        CASE LS_Bosnian       ; cText := "Bośniacki"           ; EXIT
        CASE LS_Catalan       ; cText := "Kataloński"          ; EXIT
        CASE LS_Czech         ; cText := "Czeski"              ; EXIT
        CASE LS_Welsh         ; cText := "Walijski"            ; EXIT
        CASE LS_Danish        ; cText := "Duński"              ; EXIT
        CASE LS_German        ; cText := "Niemiecki"           ; EXIT
        CASE LS_Greek         ; cText := "Grecki"              ; EXIT
        CASE LS_English       ; cText := "Angielski"           ; EXIT
        CASE LS_Esperanto     ; cText := "Esperanto"           ; EXIT
        CASE LS_Spanish       ; cText := "Hiszpański"          ; EXIT
        CASE LS_Estonian      ; cText := "Estoński"            ; EXIT
        CASE LS_Persian       ; cText := "Perski"              ; EXIT
        CASE LS_Finnish       ; cText := "Fiński"              ; EXIT
        CASE LS_French        ; cText := "Francuski"           ; EXIT
        CASE LS_Irish         ; cText := "Irlandzki"           ; EXIT
        CASE LS_Galician      ; cText := "Galicyjski"          ; EXIT
        CASE LS_Hindi         ; cText := "Hindi"               ; EXIT
        CASE LS_Croatian      ; cText := "Chorwacki"           ; EXIT
        CASE LS_HaitianCreole ; cText := "Haitański Kreolski"  ; EXIT
        CASE LS_Hungarian     ; cText := "Węgierski"           ; EXIT
        CASE LS_Armenian      ; cText := "Armeński"            ; EXIT
        CASE LS_Indonesian    ; cText := "Indonezyjski"        ; EXIT
        CASE LS_Icelandic     ; cText := "Islandzki"           ; EXIT
        CASE LS_Italian       ; cText := "Włoski"              ; EXIT
        CASE LS_Hebrew        ; cText := "Hebrajski"           ; EXIT
        CASE LS_Japanese      ; cText := "Japoński"            ; EXIT
        CASE LS_Georgian      ; cText := "Gruziński"           ; EXIT
        CASE LS_Korean        ; cText := "Koreański"           ; EXIT
        CASE LS_Latin         ; cText := "Łacina"              ; EXIT
        CASE LS_Lithuanian    ; cText := "Litewski"            ; EXIT
        CASE LS_Latvian       ; cText := "Łotewski"            ; EXIT
        CASE LS_Macedonian    ; cText := "Macedoński"          ; EXIT
        CASE LS_Malay         ; cText := "Malajski"            ; EXIT
        CASE LS_Maltese       ; cText := "Maltański"           ; EXIT
        CASE LS_Dutch         ; cText := "Holenderski"         ; EXIT
        CASE LS_Norwegian     ; cText := "Norweski"            ; EXIT
        CASE LS_Punjabi       ; cText := "Pendżabski"          ; EXIT
        CASE LS_Polish        ; cText := "Polski"              ; EXIT
        CASE LS_Portuguese    ; cText := "Portugalski"         ; EXIT
        CASE LS_Romanian      ; cText := "Rumuński"            ; EXIT
        CASE LS_Russian       ; cText := "Rosyjski"            ; EXIT
        CASE LS_Slovak        ; cText := "Słowacki"            ; EXIT
        CASE LS_Slovenian     ; cText := "Słoweński"           ; EXIT
        CASE LS_Albanian      ; cText := "Albański"            ; EXIT
        CASE LS_Serbian       ; cText := "Serbski"             ; EXIT
        CASE LS_Swedish       ; cText := "Szwedzki"            ; EXIT
        CASE LS_Swahili       ; cText := "Suahili"             ; EXIT
        CASE LS_Tamil         ; cText := "Tamilski"            ; EXIT
        CASE LS_Thai          ; cText := "Tajski"              ; EXIT
        CASE LS_Filipino      ; cText := "Filipiński"          ; EXIT
        CASE LS_Turkish       ; cText := "Turecki"             ; EXIT
        CASE LS_Ukrainian     ; cText := "Ukraiński"           ; EXIT
        CASE LS_Urdu          ; cText := "Urdu"                ; EXIT
        CASE LS_Vietnamese    ; cText := "Wietnamski"          ; EXIT
        CASE LS_Yiddish       ; cText := "Jidysz"              ; EXIT
        CASE LS_ChineseSimp   ; cText := "Chiński Uproszczony" ; EXIT
        CASE LS_ChineseTrad   ; cText := "Chiński Tradycyjny"  ; EXIT
        CASE LS_AutoDetection ; cText := "Auto-detekcja"       ; EXIT
      ENDSWITCH
      EXIT

    CASE "ru"
      SWITCH nStr
        CASE LS_File             ; cText := "файл"                                                           ; EXIT
        CASE LS_OpenInNewTab     ; cText := "Открыть в новой вкладке"                                        ; EXIT
        CASE LS_OpenInCurTab     ; cText := "Открыть в текущей вкладке"                                      ; EXIT
        CASE LS_OpenPageInNewTab ; cText := "Открыть на странице в новой вкладке"                            ; EXIT
        CASE LS_OpenPageInCurTab ; cText := "Открыть на странице в текущей вкладке"                          ; EXIT
        CASE LS_OpenFromDir      ; cText := "Открыть из каталога"                                            ; EXIT
        CASE LS_PrevPDF          ; cText := "Предыдущий PDF"                                                 ; EXIT
        CASE LS_NextPDF          ; cText := "Следующий PDF"                                                  ; EXIT
        CASE LS_FirstPDF         ; cText := "Первый PDF"                                                     ; EXIT
        CASE LS_LastPDF          ; cText := "Последний PDF"                                                  ; EXIT
        CASE LS_OpenSession      ; cText := "Открыть последнюю сессию"                                       ; EXIT
        CASE LS_RecentFiles      ; cText := "Недавние файлы"                                                 ; EXIT
        CASE LS_Rename           ; cText := "Переименовать"                                                  ; EXIT
        CASE LS_Delete           ; cText := "Удалить"                                                        ; EXIT
        CASE LS_Properties       ; cText := "Свойства"                                                       ; EXIT
        CASE LS_GoToSubDir       ; cText := "Перейти в подкаталог"                                           ; EXIT
        CASE LS_GoToParentDir    ; cText := "Перейти в родительский каталог"                                 ; EXIT
        CASE LS_ChooseDir        ; cText := "Выберите каталог"                                               ; EXIT
        CASE LS_RefreshList      ; cText := "Обновить список"                                                ; EXIT
        CASE LS_Exit             ; cText := "Выход"                                                          ; EXIT
        CASE LS_Document         ; cText := "Документ"                                                       ; EXIT
        CASE LS_Documents        ; cText := "Документы"                                                      ; EXIT
        CASE LS_SaveAs           ; cText := "Сохранить как"                                                  ; EXIT
        CASE LS_Print            ; cText := "Печать"                                                         ; EXIT
        CASE LS_PrintFile        ; cText := "Печать файл"                                                    ; EXIT
        CASE LS_SelectAllInDoc   ; cText := "Выделить все в документе"                                       ; EXIT
        CASE LS_TranslateSel     ; cText := "Перевести выделенный текст"                                     ; EXIT
        CASE LS_MoveTab          ; cText := "Переместить вкладку"                                            ; EXIT
        CASE LS_Left             ; cText := "В лево"                                                         ; EXIT
        CASE LS_Right            ; cText := "В право"                                                        ; EXIT
        CASE LS_Up               ; cText := "Вверх"                                                          ; EXIT
        CASE LS_Down             ; cText := "Вниз"                                                           ; EXIT
        CASE LS_Beginning        ; cText := "К началу"                                                       ; EXIT
        CASE LS_End              ; cText := "К концу"                                                        ; EXIT
        CASE LS_CurrDoc          ; cText := "Текущий документ (вкладку)"                                     ; EXIT
        CASE LS_DupDoc           ; cText := "Дубликаты текущего документа"                                   ; EXIT
        CASE LS_AllDup           ; cText := "Все дубликаты"                                                  ; EXIT
        CASE LS_AllInactive      ; cText := "Все неактивные"                                                 ; EXIT
        CASE LS_AllDoc           ; cText := "Все документы"                                                  ; EXIT
        CASE LS_RestoreLastTab   ; cText := "Восстановить последнюю закрытую вкладку"                        ; EXIT
        CASE LS_NewDocument      ; cText := "Новый документ"                                                 ; EXIT
        CASE LS_ChooseDoc        ; cText := "Выбрать документ/меню вкладок"                                  ; EXIT
        CASE LS_GoToFile         ; cText := "Перейти к файлу"                                                ; EXIT
        CASE LS_Tools            ; cText := "Инструменты"                                                    ; EXIT
        CASE LS_MergeSplitRotate ; cText := "Слияние/Разделение/Вращение"                                    ; EXIT
        CASE LS_SplitIntoPages   ; cText := "Разделить на отдельные страницы"                                ; EXIT
        CASE LS_Page             ; cText := "Страница"                                                       ; EXIT
        CASE LS_GoTo             ; cText := "Перейти к"                                                      ; EXIT
        CASE LS_Prev             ; cText := "Предыдущая"                                                     ; EXIT
        CASE LS_Next             ; cText := "Следущая"                                                       ; EXIT
        CASE LS_First            ; cText := "Первая"                                                         ; EXIT
        CASE LS_Last             ; cText := "Последняя"                                                      ; EXIT
        CASE LS_Find             ; cText := "Найти"                                                          ; EXIT
        CASE LS_Text             ; cText := "Текст"                                                          ; EXIT
        CASE LS_PrevOccur        ; cText := "Предыдущее вхождение"                                           ; EXIT
        CASE LS_NextOccur        ; cText := "Следующее вхождение"                                            ; EXIT
        CASE LS_Zoom             ; cText := "Масштаб"                                                        ; EXIT
        CASE LS_SizeDown         ; cText := "Уменьшить"                                                      ; EXIT
        CASE LS_SizeUp           ; cText := "Увеличить"                                                      ; EXIT
        CASE LS_ZoomFactor       ; cText := "Указать масштаб"                                                ; EXIT
        CASE LS_FitPage          ; cText := "По размеру страницы"                                            ; EXIT
        CASE LS_ActualSize       ; cText := "Настоящий размер"                                               ; EXIT
        CASE LS_FitWidth         ; cText := "По ширине"                                                      ; EXIT
        CASE LS_Rotate           ; cText := "Вращать"                                                        ; EXIT
        CASE LS_View             ; cText := "Вид"                                                            ; EXIT
        CASE LS_MenuBar          ; cText := "Строка меню"                                                    ; EXIT
        CASE LS_StatusBar        ; cText := "Строка состояния"                                               ; EXIT
        CASE LS_FilesPanel       ; cText := "Панель файлов"                                                  ; EXIT
        CASE LS_ToolBar          ; cText := "Панель инструментов PDF"                                        ; EXIT
        CASE LS_Bookmarks        ; cText := "Закладки PDF"                                                   ; EXIT
        CASE LS_Show             ; cText := "Показать"                                                       ; EXIT
        CASE LS_ExpandAll        ; cText := "Расширить все"                                                  ; EXIT
        CASE LS_CollapseAll      ; cText := "Свернуть все"                                                   ; EXIT
        CASE LS_Settings         ; cText := "Настройки"                                                      ; EXIT
        CASE LS_Options          ; cText := "Параметры"                                                      ; EXIT
        CASE LS_General          ; cText := "Общие"                                                          ; EXIT
        CASE LS_Language         ; cText := "Язык:"                                                          ; EXIT
        CASE LS_NotRunAppTwice   ; cText := "Не запускайте PDFview дважды"                                   ; EXIT
        CASE LS_NotOpenPDFTwice  ; cText := "Не открывать PDF-файл дважды"                                   ; EXIT
        CASE LS_OpenAtOnce       ; cText := "Открыть PDF немедленно (панель файлов)"                         ; EXIT
        CASE LS_RestSession      ; cText := "Восстановить последнюю сессию на старте"                        ; EXIT
        CASE LS_EscExit          ; cText := "Esc - выход"                                                    ; EXIT
        CASE LS_TabGoToFile      ; cText := "Изменение вкладки, идти к файлу в панели файлов"                ; EXIT
        CASE LS_NewTabOpen       ; cText := "Новую вкладку открыть:"                                         ; EXIT
        CASE LS_BeforeCurrent    ; cText := "Перед текущей"                                                  ; EXIT
        CASE LS_AfterCurrent     ; cText := "После текущей"                                                  ; EXIT
        CASE LS_AtBeginning      ; cText := "В начале"                                                       ; EXIT
        CASE LS_AtEnd            ; cText := "В конце"                                                        ; EXIT
        CASE LS_TabsWidth        ; cText := "Ширина вкладок в символах, (0 - без лимита):"                   ; EXIT
        CASE LS_SumatraDir       ; cText := "Каталог SumatraPDF.exe"                                         ; EXIT
        CASE LS_PDFtkDir         ; cText := "Каталог PDFtk.exe"                                              ; EXIT
        CASE LS_ColorsFilesPanel ; cText := "Цвета в панели файлов"                                          ; EXIT
        CASE LS_Background       ; cText := "Фон"                                                            ; EXIT
        CASE LS_Directories      ; cText := "Каталоги"                                                       ; EXIT
        CASE LS_SelDirPanelA     ; cText := "Выбранный каталог - панель активна"                             ; EXIT
        CASE LS_SelDirPanelNA    ; cText := "Выбранный каталог - панель неактивна"                           ; EXIT
        CASE LS_Files            ; cText := "Файлы"                                                          ; EXIT
        CASE LS_SelFilePanelA    ; cText := "Выбранный файл - панель активна"                                ; EXIT
        CASE LS_SelFilePanelNA   ; cText := "Выбранный файл - панель неактивна"                              ; EXIT
        CASE LS_Default          ; cText := "По умолчанию"                                                   ; EXIT
        CASE LS_AboutPDFview     ; cText := "О программе PDFview"                                            ; EXIT
        CASE LS_AboutSumatra     ; cText := "О программе SumatraPDF"                                         ; EXIT
        CASE LS_AppRunning       ; cText := "Программа уже работает!"                                        ; EXIT
        CASE LS_Drive            ; cText := "Диск"                                                           ; EXIT
        CASE LS_NoDisk           ; cText := "Диск не доступен!"                                              ; EXIT
        CASE LS_NoFile           ; cText := "Файл не существует!"                                            ; EXIT
        CASE LS_InvalidVersion   ; cText := "Неверная версия SumatraPDF!"                                    ; EXIT
        CASE LS_UseVersion       ; cText := "Используйте версию 3.1.2 или 3.2"                               ; EXIT
        CASE LS_SetPathTo        ; cText := "Установить путь к:"                                             ; EXIT
        CASE LS_ListRefresh      ; cText := "Список будет обновлен."                                         ; EXIT
        CASE LS_Path             ; cText := "Путь"                                                           ; EXIT
        CASE LS_Name             ; cText := "Имя"                                                            ; EXIT
        CASE LS_NewName          ; cText := "Новое имя"                                                      ; EXIT
        CASE LS_IncorrectName    ; cText := "Неверное имя!"                                                  ; EXIT
        CASE LS_RenameDir        ; cText := "Переименуйте каталог"                                           ; EXIT
        CASE LS_DeleteDir        ; cText := "Удалите каталог"                                                ; EXIT
        CASE LS_RenameFile       ; cText := "Переименуйте файл"                                              ; EXIT
        CASE LS_DeleteFile       ; cText := "Удалите файл"                                                   ; EXIT
        CASE LS_CantRename       ; cText := "Невозможно переименовать!"                                      ; EXIT
        CASE LS_CantDelete       ; cText := "Невозможно удалить!"                                            ; EXIT
        CASE LS_DirInUse         ; cText := "Каталог в настоящее время используется."                        ; EXIT
        CASE LS_FileInUse        ; cText := "Файл в настоящее время используется."                           ; EXIT
        CASE LS_DirExists        ; cText := "Каталог с заданным именем уже существует."                      ; EXIT
        CASE LS_FileExists       ; cText := "Файл с заданным именем уже существует."                         ; EXIT
        CASE LS_DirNotEmpty      ; cText := "Каталог не пуст."                                               ; EXIT
        CASE LS_DeleteAllContent ; cText := "Удалить все содержимое?"                                        ; EXIT
        CASE LS_CantDeleteAll    ; cText := "Не удалось удалить некоторые файлы/подкаталоги!"                ; EXIT
        CASE LS_OpenFilePage     ; cText := "Открыть файл на странице"                                       ; EXIT
        CASE LS_PageNum          ; cText := "Номер страницы:"                                                ; EXIT
        CASE LS_SelSumatraDir    ; cText := "Выберите папку SumatraPDF:"                                     ; EXIT
        CASE LS_SelPDFtkDir      ; cText := "Выберите папку PDFtk:"                                          ; EXIT
        CASE LS_OnlyNames        ; cText := "Только имена"                                                   ; EXIT
        CASE LS_FilesAmount      ; cText := "Количество файлов:"                                             ; EXIT
        CASE LS_Remove           ; cText := "Удалить"                                                        ; EXIT
        CASE LS_RemoveNonExist   ; cText := "Удалить несуществующие"                                         ; EXIT
        CASE LS_RemoveAll        ; cText := "Удалить все"                                                    ; EXIT
        CASE LS_GoogleTranslator ; cText := "Переводчик Google"                                              ; EXIT
        CASE LS_Translate        ; cText := "Перевести"                                                      ; EXIT
        CASE LS_TranslateError   ; cText := "Произошла ошибка, не может перевести!"                          ; EXIT
        CASE LS_OutputDir        ; cText := "Каталог назначения:"                                            ; EXIT
        CASE LS_TargetFiles      ; cText := "Файлы целевые:"                                                 ; EXIT
        CASE LS_PageRanges       ; cText := "Диапазоны страниц"                                              ; EXIT
        CASE LS_RangeCanBe       ; cText := "Диапазон может быть одна страница или ОтСтраницы-КСтранице."    ; EXIT
        CASE LS_RangeEmpty       ; cText := "Пустой диапазон означает все страницы документа."               ; EXIT
        CASE LS_RangeSeparator   ; cText := "Сепаратор диапазона является запятая или точка с запятой."      ; EXIT
        CASE LS_LastPageNum      ; cText := "номер последней страницы"                                       ; EXIT
        CASE LS_PageNumFromEnd   ; cText := "Номер страницы из конца (использовать перед номером страницы):" ; EXIT
        CASE LS_EvenOddPages     ; cText := "Четные/нечетные страницы (использовать в конце диапазона):"     ; EXIT
        CASE LS_EvenNum          ; cText := "четные"                                                         ; EXIT
        CASE LS_OddNum           ; cText := "нечетные"                                                       ; EXIT
        CASE LS_RotatePages      ; cText := "Поворот страниц в диапазоне (использовать после диапазона):"    ; EXIT
        CASE LS_Example          ; cText := "Пример:"                                                        ; EXIT
        CASE LS_SaveBooks        ; cText := "Сохранить закладки из документа в текстовом файле"              ; EXIT
        CASE LS_RemoveBooks      ; cText := "Удалить закладки из документа"                                  ; EXIT
        CASE LS_InsertBooks      ; cText := "Вставить закладки в документ из следующего текстового файла:"   ; EXIT
        CASE LS_PassProtect      ; cText := "Защита паролем целевого документа"                              ; EXIT
        CASE LS_OwnerPass        ; cText := "Пароль владельца:"                                              ; EXIT
        CASE LS_UserPass         ; cText := "Пароль пользователя:"                                           ; EXIT
        CASE LS_OwnerPassReq     ; cText := "Требуется пароль владельца"                                     ; EXIT
        CASE LS_ShowPass         ; cText := "Показать пароли"                                                ; EXIT
        CASE LS_TotalPages       ; cText := "Количество страниц в целевом документе:"                        ; EXIT
        CASE LS_AllOpenedDocs    ; cText := "Все открытые документы"                                         ; EXIT
        CASE LS_OtherDocs        ; cText := "Другие документы"                                               ; EXIT
        CASE LS_Wait             ; cText := "Подожди"                                                        ; EXIT
        CASE LS_Done             ; cText := "Готово!"                                                        ; EXIT
        CASE LS_PDFtkWorking     ; cText := "PDFtk работает"                                                 ; EXIT
        CASE LS_CopyTarget       ; cText := "копирование целевых файлов"                                     ; EXIT
        CASE LS_RangesError      ; cText := "Ошибка в диапазоне страниц!"                                    ; EXIT
        CASE LS_NoBookmarks      ; cText := "Нет закладок в этом файле!"                                     ; EXIT
        CASE LS_CantRunPDFtk     ; cText := "Не могу запустить PDFtk.exe!"                                   ; EXIT
        CASE LS_PDFtkError       ; cText := "Ошибка Pdftk"                                                   ; EXIT
        CASE LS_FileOverwrite    ; cText := "Файл уже существует. Перезаписать его?"                         ; EXIT
        CASE LS_FileCopyError    ; cText := "Ошибка копирования файла!"                                      ; EXIT
        CASE LS_PDFviewUsing     ; cText := "Просмотр, деление и слияние PDF с помощью:"                     ; EXIT
        CASE LS_DevelopedIn      ; cText := "Разработано в:"                                                 ; EXIT
        CASE LS_Author           ; cText := "Автор:"                                                         ; EXIT
        CASE LS_SourceCode       ; cText := "Исходный код"                                                   ; EXIT
        CASE LS_Open             ; cText := "Открыть"                                                        ; EXIT
        CASE LS_Add              ; cText := "Добавить"                                                       ; EXIT
        CASE LS_AddAbove         ; cText := "Добавить выше"                                                  ; EXIT
        CASE LS_Duplicate        ; cText := "Дублировать"                                                    ; EXIT
        CASE LS_EditRanges       ; cText := "Изменить диапазоны"                                             ; EXIT
        CASE LS_Make             ; cText := "Сделать"                                                        ; EXIT
        CASE LS_Close            ; cText := "Закрыть"                                                        ; EXIT
        CASE LS_OK               ; cText := "OK"                                                             ; EXIT
        CASE LS_Cancel           ; cText := "Отмена"                                                         ; EXIT
        CASE LS_Yes              ; cText := "Да"                                                             ; EXIT
        CASE LS_YesForAll        ; cText := "Да для всех"                                                    ; EXIT
        CASE LS_Repeat           ; cText := "Повторять"                                                      ; EXIT
        CASE LS_Skip             ; cText := "Пропускать"                                                     ; EXIT

        CASE LS_Afrikaans     ; cText := "Африкаанс"              ; EXIT
        CASE LS_Arabic        ; cText := "Арабский"               ; EXIT
        CASE LS_Azerbaijani   ; cText := "Азербайджанский"        ; EXIT
        CASE LS_Belarusian    ; cText := "Белорусский"            ; EXIT
        CASE LS_Bulgarian     ; cText := "Болгарский"             ; EXIT
        CASE LS_Bosnian       ; cText := "Боснийский"             ; EXIT
        CASE LS_Catalan       ; cText := "Каталонский"            ; EXIT
        CASE LS_Czech         ; cText := "Чешский"                ; EXIT
        CASE LS_Welsh         ; cText := "Валлийский"             ; EXIT
        CASE LS_Danish        ; cText := "Датский"                ; EXIT
        CASE LS_German        ; cText := "Немецкий"               ; EXIT
        CASE LS_Greek         ; cText := "Греческий"              ; EXIT
        CASE LS_English       ; cText := "Английский"             ; EXIT
        CASE LS_Esperanto     ; cText := "Эсперанто"              ; EXIT
        CASE LS_Spanish       ; cText := "Испанский"              ; EXIT
        CASE LS_Estonian      ; cText := "Эстонский"              ; EXIT
        CASE LS_Persian       ; cText := "Персидский"             ; EXIT
        CASE LS_Finnish       ; cText := "Финский"                ; EXIT
        CASE LS_French        ; cText := "Французский"            ; EXIT
        CASE LS_Irish         ; cText := "Ирландский"             ; EXIT
        CASE LS_Galician      ; cText := "Галисийский"            ; EXIT
        CASE LS_Hindi         ; cText := "Хинди"                  ; EXIT
        CASE LS_Croatian      ; cText := "Хорватский"             ; EXIT
        CASE LS_HaitianCreole ; cText := "Гаитянский креольский"  ; EXIT
        CASE LS_Hungarian     ; cText := "Венгерский"             ; EXIT
        CASE LS_Armenian      ; cText := "Армянский"              ; EXIT
        CASE LS_Indonesian    ; cText := "Индонезийский"          ; EXIT
        CASE LS_Icelandic     ; cText := "Исландский"             ; EXIT
        CASE LS_Italian       ; cText := "Итальянский"            ; EXIT
        CASE LS_Hebrew        ; cText := "Еврейский"              ; EXIT
        CASE LS_Japanese      ; cText := "Японский"               ; EXIT
        CASE LS_Georgian      ; cText := "Грузинский"             ; EXIT
        CASE LS_Korean        ; cText := "Корейский"              ; EXIT
        CASE LS_Latin         ; cText := "Латынь"                 ; EXIT
        CASE LS_Lithuanian    ; cText := "Литовский"              ; EXIT
        CASE LS_Latvian       ; cText := "Латышский"              ; EXIT
        CASE LS_Macedonian    ; cText := "Македонский"            ; EXIT
        CASE LS_Malay         ; cText := "Малайский"              ; EXIT
        CASE LS_Maltese       ; cText := "Мальтийский"            ; EXIT
        CASE LS_Dutch         ; cText := "Голландский"            ; EXIT
        CASE LS_Norwegian     ; cText := "Норвежский"             ; EXIT
        CASE LS_Punjabi       ; cText := "Панджаби"               ; EXIT
        CASE LS_Polish        ; cText := "Польский"               ; EXIT
        CASE LS_Portuguese    ; cText := "Португальский"          ; EXIT
        CASE LS_Romanian      ; cText := "Румынский"              ; EXIT
        CASE LS_Russian       ; cText := "Русский"                ; EXIT
        CASE LS_Slovak        ; cText := "Словацкий"              ; EXIT
        CASE LS_Slovenian     ; cText := "Словенский"             ; EXIT
        CASE LS_Albanian      ; cText := "Албанский"              ; EXIT
        CASE LS_Serbian       ; cText := "Сербский"               ; EXIT
        CASE LS_Swedish       ; cText := "Шведский"               ; EXIT
        CASE LS_Swahili       ; cText := "Суахили"                ; EXIT
        CASE LS_Tamil         ; cText := "Тамильский"             ; EXIT
        CASE LS_Thai          ; cText := "Тайский"                ; EXIT
        CASE LS_Filipino      ; cText := "Филиппинский"           ; EXIT
        CASE LS_Turkish       ; cText := "Турецкий"               ; EXIT
        CASE LS_Ukrainian     ; cText := "Украинский"             ; EXIT
        CASE LS_Urdu          ; cText := "Урду"                   ; EXIT
        CASE LS_Vietnamese    ; cText := "Вьетнамский"            ; EXIT
        CASE LS_Yiddish       ; cText := "Идиш"                   ; EXIT
        CASE LS_ChineseSimp   ; cText := "Китайский Упрощенный"   ; EXIT
        CASE LS_ChineseTrad   ; cText := "Китайский Традиционный" ; EXIT
        CASE LS_AutoDetection ; cText := "Авто-определение"       ; EXIT
      ENDSWITCH
      EXIT
  ENDSWITCH

  IF Empty(cText)
    SWITCH nStr
      CASE LS_File             ; cText := "&File"                                                    ; EXIT
      CASE LS_OpenInNewTab     ; cText := "Open in &new tab"                                         ; EXIT
      CASE LS_OpenInCurTab     ; cText := "Open in &current tab"                                     ; EXIT
      CASE LS_OpenPageInNewTab ; cText := "Open at &page in new tab"                                 ; EXIT
      CASE LS_OpenPageInCurTab ; cText := "Open at page in current &tab"                             ; EXIT
      CASE LS_OpenFromDir      ; cText := "Open from &directory"                                     ; EXIT
      CASE LS_PrevPDF          ; cText := "&Previous PDF"                                            ; EXIT
      CASE LS_NextPDF          ; cText := "&Next PDF"                                                ; EXIT
      CASE LS_FirstPDF         ; cText := "&First PDF"                                               ; EXIT
      CASE LS_LastPDF          ; cText := "&Last PDF"                                                ; EXIT
      CASE LS_OpenSession      ; cText := "Open last &session"                                       ; EXIT
      CASE LS_RecentFiles      ; cText := "Recent &files"                                            ; EXIT
      CASE LS_Rename           ; cText := "&Rename"                                                  ; EXIT
      CASE LS_Delete           ; cText := "&Delete"                                                  ; EXIT
      CASE LS_Properties       ; cText := "Prop&erties"                                              ; EXIT
      CASE LS_GoToSubDir       ; cText := "Go to subdirectory"                                       ; EXIT
      CASE LS_GoToParentDir    ; cText := "Go to parent directory"                                   ; EXIT
      CASE LS_ChooseDir        ; cText := "Choose &directory"                                        ; EXIT
      CASE LS_RefreshList      ; cText := "&Refresh list"                                            ; EXIT
      CASE LS_Exit             ; cText := "E&xit"                                                    ; EXIT
      CASE LS_Document         ; cText := "&Document"                                                ; EXIT
      CASE LS_Documents        ; cText := "Documents"                                                ; EXIT
      CASE LS_SaveAs           ; cText := "&Save as"                                                 ; EXIT
      CASE LS_Print            ; cText := "&Print"                                                   ; EXIT
      CASE LS_PrintFile        ; cText := "Print file"                                               ; EXIT
      CASE LS_SelectAllInDoc   ; cText := "Select &all in document"                                  ; EXIT
      CASE LS_TranslateSel     ; cText := "&Translate selected text"                                 ; EXIT
      CASE LS_MoveTab          ; cText := "&Move tab"                                                ; EXIT
      CASE LS_Left             ; cText := "&Left"                                                    ; EXIT
      CASE LS_Right            ; cText := "&Right"                                                   ; EXIT
      CASE LS_Up               ; cText := "&Up"                                                      ; EXIT
      CASE LS_Down             ; cText := "&Down"                                                    ; EXIT
      CASE LS_Beginning        ; cText := "&Beginning"                                               ; EXIT
      CASE LS_End              ; cText := "&End"                                                     ; EXIT
      CASE LS_CurrDoc          ; cText := "&Current document (tab)"                                  ; EXIT
      CASE LS_DupDoc           ; cText := "&Duplicates of current document"                          ; EXIT
      CASE LS_AllDup           ; cText := "All duplicates"                                           ; EXIT
      CASE LS_AllInactive      ; cText := "All inactive"                                             ; EXIT
      CASE LS_AllDoc           ; cText := "All documents"                                            ; EXIT
      CASE LS_RestoreLastTab   ; cText := "&Restore last closed tab"                                 ; EXIT
      CASE LS_NewDocument      ; cText := "&New document"                                            ; EXIT
      CASE LS_ChooseDoc        ; cText := "Choose &document/tabs menu"                               ; EXIT
      CASE LS_GoToFile         ; cText := "&Go to file"                                              ; EXIT
      CASE LS_Tools            ; cText := "T&ools"                                                   ; EXIT
      CASE LS_MergeSplitRotate ; cText := "&Merge/Split/Rotate"                                      ; EXIT
      CASE LS_SplitIntoPages   ; cText := "&Split into single pages"                                 ; EXIT
      CASE LS_Page             ; cText := "&Page"                                                    ; EXIT
      CASE LS_GoTo             ; cText := "&Go to"                                                   ; EXIT
      CASE LS_Prev             ; cText := "&Previous"                                                ; EXIT
      CASE LS_Next             ; cText := "&Next"                                                    ; EXIT
      CASE LS_First            ; cText := "&First"                                                   ; EXIT
      CASE LS_Last             ; cText := "&Last"                                                    ; EXIT
      CASE LS_Find             ; cText := "Fi&nd"                                                    ; EXIT
      CASE LS_Text             ; cText := "&Text"                                                    ; EXIT
      CASE LS_PrevOccur        ; cText := "&Previous occurence"                                      ; EXIT
      CASE LS_NextOccur        ; cText := "&Next occurence"                                          ; EXIT
      CASE LS_Zoom             ; cText := "&Zoom"                                                    ; EXIT
      CASE LS_SizeDown         ; cText := "Size &down"                                               ; EXIT
      CASE LS_SizeUp           ; cText := "Size &up"                                                 ; EXIT
      CASE LS_ZoomFactor       ; cText := "&Zoom factor"                                             ; EXIT
      CASE LS_FitPage          ; cText := "Fit &page"                                                ; EXIT
      CASE LS_ActualSize       ; cText := "&Actual size"                                             ; EXIT
      CASE LS_FitWidth         ; cText := "Fit &width"                                               ; EXIT
      CASE LS_Rotate           ; cText := "&Rotate"                                                  ; EXIT
      CASE LS_View             ; cText := "&View"                                                    ; EXIT
      CASE LS_MenuBar          ; cText := "&Menu bar"                                                ; EXIT
      CASE LS_StatusBar        ; cText := "&Status bar"                                              ; EXIT
      CASE LS_FilesPanel       ; cText := "&Files panel"                                             ; EXIT
      CASE LS_ToolBar          ; cText := "PDF &toolbar"                                             ; EXIT
      CASE LS_Bookmarks        ; cText := "PDF &bookmarks"                                           ; EXIT
      CASE LS_Show             ; cText := "&Show"                                                    ; EXIT
      CASE LS_ExpandAll        ; cText := "&Expand all"                                              ; EXIT
      CASE LS_CollapseAll      ; cText := "&Collapse all"                                            ; EXIT
      CASE LS_Settings         ; cText := "&Settings"                                                ; EXIT
      CASE LS_Options          ; cText := "&Options"                                                 ; EXIT
      CASE LS_General          ; cText := "General"                                                  ; EXIT
      CASE LS_Language         ; cText := "&Language:"                                               ; EXIT
      CASE LS_NotRunAppTwice   ; cText := "Don't run PDF&view twice"                                 ; EXIT
      CASE LS_NotOpenPDFTwice  ; cText := "&Don't open PDF file twice"                               ; EXIT
      CASE LS_OpenAtOnce       ; cText := "&Open PDF immediately (files panel)"                      ; EXIT
      CASE LS_RestSession      ; cText := "&Restore last session on start"                           ; EXIT
      CASE LS_EscExit          ; cText := "&Esc - exit program"                                      ; EXIT
      CASE LS_TabGoToFile      ; cText := "Changing tab, &go to file in files panel"                 ; EXIT
      CASE LS_NewTabOpen       ; cText := "&New tab open:"                                           ; EXIT
      CASE LS_BeforeCurrent    ; cText := "Before current"                                           ; EXIT
      CASE LS_AfterCurrent     ; cText := "After current"                                            ; EXIT
      CASE LS_AtBeginning      ; cText := "At beginning"                                             ; EXIT
      CASE LS_AtEnd            ; cText := "At end"                                                   ; EXIT
      CASE LS_TabsWidth        ; cText := "&Tabs width in characters, (0 - without limit):"          ; EXIT
      CASE LS_SumatraDir       ; cText := "&SumatraPDF.exe directory"                                ; EXIT
      CASE LS_PDFtkDir         ; cText := "&PDFtk.exe directory"                                     ; EXIT
      CASE LS_ColorsFilesPanel ; cText := "Colors in files panel"                                    ; EXIT
      CASE LS_Background       ; cText := "Background"                                               ; EXIT
      CASE LS_Directories      ; cText := "Directories"                                              ; EXIT
      CASE LS_SelDirPanelA     ; cText := "Selected directory - panel active"                        ; EXIT
      CASE LS_SelDirPanelNA    ; cText := "Selected directory - panel non-active"                    ; EXIT
      CASE LS_Files            ; cText := "Files"                                                    ; EXIT
      CASE LS_SelFilePanelA    ; cText := "Selected file - panel active"                             ; EXIT
      CASE LS_SelFilePanelNA   ; cText := "Selected file - panel non-active"                         ; EXIT
      CASE LS_Default          ; cText := "Default"                                                  ; EXIT
      CASE LS_AboutPDFview     ; cText := "About &PDFview"                                           ; EXIT
      CASE LS_AboutSumatra     ; cText := "About &SumatraPDF"                                        ; EXIT
      CASE LS_AppRunning       ; cText := "Program already is running!"                              ; EXIT
      CASE LS_Drive            ; cText := "Drive"                                                    ; EXIT
      CASE LS_NoDisk           ; cText := "Disk is not available!"                                   ; EXIT
      CASE LS_NoFile           ; cText := "File does not exist!"                                     ; EXIT
      CASE LS_InvalidVersion   ; cText := "Invalid version of SumatraPDF!"                           ; EXIT
      CASE LS_UseVersion       ; cText := "Use version 3.1.2 or 3.2"                                 ; EXIT
      CASE LS_SetPathTo        ; cText := "Set path to:"                                             ; EXIT
      CASE LS_ListRefresh      ; cText := "List will be refreshed."                                  ; EXIT
      CASE LS_Path             ; cText := "Path"                                                     ; EXIT
      CASE LS_Name             ; cText := "Name"                                                     ; EXIT
      CASE LS_NewName          ; cText := "New name"                                                 ; EXIT
      CASE LS_IncorrectName    ; cText := "Incorrect name!"                                          ; EXIT
      CASE LS_RenameDir        ; cText := "Rename directory"                                         ; EXIT
      CASE LS_DeleteDir        ; cText := "Delete directory"                                         ; EXIT
      CASE LS_RenameFile       ; cText := "Rename file"                                              ; EXIT
      CASE LS_DeleteFile       ; cText := "Delete file"                                              ; EXIT
      CASE LS_CantRename       ; cText := "Can not rename!"                                          ; EXIT
      CASE LS_CantDelete       ; cText := "Can not delete!"                                          ; EXIT
      CASE LS_DirInUse         ; cText := "Directory is currently in use."                           ; EXIT
      CASE LS_FileInUse        ; cText := "File is currently in use."                                ; EXIT
      CASE LS_DirExists        ; cText := "Directory with given name already exists."                ; EXIT
      CASE LS_FileExists       ; cText := "File with given name already exists."                     ; EXIT
      CASE LS_DirNotEmpty      ; cText := "Directory is not empty."                                  ; EXIT
      CASE LS_DeleteAllContent ; cText := "Delete all content?"                                      ; EXIT
      CASE LS_CantDeleteAll    ; cText := "Some files/subdirectories could not be deleted!"          ; EXIT
      CASE LS_OpenFilePage     ; cText := "Open file at page"                                        ; EXIT
      CASE LS_PageNum          ; cText := "Page number:"                                             ; EXIT
      CASE LS_SelSumatraDir    ; cText := "Select SumatraPDF directory:"                             ; EXIT
      CASE LS_SelPDFtkDir      ; cText := "Select PDFtk directory:"                                  ; EXIT
      CASE LS_OnlyNames        ; cText := "Only &names"                                              ; EXIT
      CASE LS_FilesAmount      ; cText := "Amount of &files:"                                        ; EXIT
      CASE LS_Remove           ; cText := "&Remove"                                                  ; EXIT
      CASE LS_RemoveNonExist   ; cText := "Remove &non-existent"                                     ; EXIT
      CASE LS_RemoveAll        ; cText := "Remove &all"                                              ; EXIT
      CASE LS_GoogleTranslator ; cText := "Google Translator"                                        ; EXIT
      CASE LS_Translate        ; cText := "Translate"                                                ; EXIT
      CASE LS_TranslateError   ; cText := "Error has occured, can not translate!"                    ; EXIT
      CASE LS_OutputDir        ; cText := "Output directory:"                                        ; EXIT
      CASE LS_TargetFiles      ; cText := "Target files:"                                            ; EXIT
      CASE LS_PageRanges       ; cText := "Page ranges"                                              ; EXIT
      CASE LS_RangeCanBe       ; cText := "Range can be single page or FromPage-ToPage."             ; EXIT
      CASE LS_RangeEmpty       ; cText := "Empty range means all pages of the document."             ; EXIT
      CASE LS_RangeSeparator   ; cText := "Range separator is comma or semicolon."                   ; EXIT
      CASE LS_LastPageNum      ; cText := "last page number"                                         ; EXIT
      CASE LS_PageNumFromEnd   ; cText := "Page number from end (use before page number):"           ; EXIT
      CASE LS_EvenOddPages     ; cText := "Even/odd pages (use at end of range):"                    ; EXIT
      CASE LS_EvenNum          ; cText := "even-numbered"                                            ; EXIT
      CASE LS_OddNum           ; cText := "odd-numbered"                                             ; EXIT
      CASE LS_RotatePages      ; cText := "Rotate pages in range (use after range):"                 ; EXIT
      CASE LS_Example          ; cText := "Example:"                                                 ; EXIT
      CASE LS_SaveBooks        ; cText := "Save bookmarks from document in text file"                ; EXIT
      CASE LS_RemoveBooks      ; cText := "Remove bookmarks from document"                           ; EXIT
      CASE LS_InsertBooks      ; cText := "Insert bookmarks into document from following text file:" ; EXIT
      CASE LS_PassProtect      ; cText := "Password protection of target document"                   ; EXIT
      CASE LS_OwnerPass        ; cText := "Owner password:"                                          ; EXIT
      CASE LS_UserPass         ; cText := "User password:"                                           ; EXIT
      CASE LS_OwnerPassReq     ; cText := "Owner password required"                                  ; EXIT
      CASE LS_ShowPass         ; cText := "Show passwords"                                           ; EXIT
      CASE LS_TotalPages       ; cText := "Total pages in target document:"                          ; EXIT
      CASE LS_AllOpenedDocs    ; cText := "All opened documents"                                     ; EXIT
      CASE LS_OtherDocs        ; cText := "Other documents"                                          ; EXIT
      CASE LS_Wait             ; cText := "Wait"                                                     ; EXIT
      CASE LS_Done             ; cText := "Done!"                                                    ; EXIT
      CASE LS_PDFtkWorking     ; cText := "PDFtk is working"                                         ; EXIT
      CASE LS_CopyTarget       ; cText := "copying target files"                                     ; EXIT
      CASE LS_RangesError      ; cText := "Error in page ranges!"                                    ; EXIT
      CASE LS_NoBookmarks      ; cText := "No bookmarks in this file!"                               ; EXIT
      CASE LS_CantRunPDFtk     ; cText := "Can not run PDFtk.exe!"                                   ; EXIT
      CASE LS_PDFtkError       ; cText := "PDFtk error"                                              ; EXIT
      CASE LS_FileOverwrite    ; cText := "File already exists. Overwrite it?"                       ; EXIT
      CASE LS_FileCopyError    ; cText := "File copy error!"                                         ; EXIT
      CASE LS_PDFviewUsing     ; cText := "PDF view, split and merge using:"                         ; EXIT
      CASE LS_DevelopedIn      ; cText := "Developed in:"                                            ; EXIT
      CASE LS_Author           ; cText := "Author:"                                                  ; EXIT
      CASE LS_SourceCode       ; cText := "Source code"                                              ; EXIT
      CASE LS_Open             ; cText := "&Open"                                                    ; EXIT
      CASE LS_Add              ; cText := "&Add"                                                     ; EXIT
      CASE LS_AddAbove         ; cText := "Add above"                                                ; EXIT
      CASE LS_Duplicate        ; cText := "Duplicate"                                                ; EXIT
      CASE LS_EditRanges       ; cText := "Edit ranges"                                              ; EXIT
      CASE LS_Make             ; cText := "&Make"                                                    ; EXIT
      CASE LS_Close            ; cText := "&Close"                                                   ; EXIT
      CASE LS_OK               ; cText := "&OK"                                                      ; EXIT
      CASE LS_Cancel           ; cText := "&Cancel"                                                  ; EXIT
      CASE LS_Yes              ; cText := "&Yes"                                                     ; EXIT
      CASE LS_YesForAll        ; cText := "Yes for &all"                                             ; EXIT
      CASE LS_Repeat           ; cText := "&Repeat"                                                  ; EXIT
      CASE LS_Skip             ; cText := "&Skip"                                                    ; EXIT

      CASE LS_Afrikaans     ; cText := "Afrikaans"           ; EXIT
      CASE LS_Arabic        ; cText := "Arabic"              ; EXIT
      CASE LS_Azerbaijani   ; cText := "Azerbaijani"         ; EXIT
      CASE LS_Belarusian    ; cText := "Belarusian"          ; EXIT
      CASE LS_Bulgarian     ; cText := "Bulgarian"           ; EXIT
      CASE LS_Bosnian       ; cText := "Bosnian"             ; EXIT
      CASE LS_Catalan       ; cText := "Catalan"             ; EXIT
      CASE LS_Czech         ; cText := "Czech"               ; EXIT
      CASE LS_Welsh         ; cText := "Welsh"               ; EXIT
      CASE LS_Danish        ; cText := "Danish"              ; EXIT
      CASE LS_German        ; cText := "German"              ; EXIT
      CASE LS_Greek         ; cText := "Greek"               ; EXIT
      CASE LS_English       ; cText := "English"             ; EXIT
      CASE LS_Esperanto     ; cText := "Esperanto"           ; EXIT
      CASE LS_Spanish       ; cText := "Spanish"             ; EXIT
      CASE LS_Estonian      ; cText := "Estonian"            ; EXIT
      CASE LS_Persian       ; cText := "Persian"             ; EXIT
      CASE LS_Finnish       ; cText := "Finnish"             ; EXIT
      CASE LS_French        ; cText := "French"              ; EXIT
      CASE LS_Irish         ; cText := "Irish"               ; EXIT
      CASE LS_Galician      ; cText := "Galician"            ; EXIT
      CASE LS_Hindi         ; cText := "Hindi"               ; EXIT
      CASE LS_Croatian      ; cText := "Croatian"            ; EXIT
      CASE LS_HaitianCreole ; cText := "Haitian Creole"      ; EXIT
      CASE LS_Hungarian     ; cText := "Hungarian"           ; EXIT
      CASE LS_Armenian      ; cText := "Armenian"            ; EXIT
      CASE LS_Indonesian    ; cText := "Indonesian"          ; EXIT
      CASE LS_Icelandic     ; cText := "Icelandic"           ; EXIT
      CASE LS_Italian       ; cText := "Italian"             ; EXIT
      CASE LS_Hebrew        ; cText := "Hebrew"              ; EXIT
      CASE LS_Japanese      ; cText := "Japanese"            ; EXIT
      CASE LS_Georgian      ; cText := "Georgian"            ; EXIT
      CASE LS_Korean        ; cText := "Korean"              ; EXIT
      CASE LS_Latin         ; cText := "Latin"               ; EXIT
      CASE LS_Lithuanian    ; cText := "Lithuanian"          ; EXIT
      CASE LS_Latvian       ; cText := "Latvian"             ; EXIT
      CASE LS_Macedonian    ; cText := "Macedonian"          ; EXIT
      CASE LS_Malay         ; cText := "Malay"               ; EXIT
      CASE LS_Maltese       ; cText := "Maltese"             ; EXIT
      CASE LS_Dutch         ; cText := "Dutch"               ; EXIT
      CASE LS_Norwegian     ; cText := "Norwegian"           ; EXIT
      CASE LS_Punjabi       ; cText := "Punjabi"             ; EXIT
      CASE LS_Polish        ; cText := "Polish"              ; EXIT
      CASE LS_Portuguese    ; cText := "Portuguese"          ; EXIT
      CASE LS_Romanian      ; cText := "Romanian"            ; EXIT
      CASE LS_Russian       ; cText := "Russian"             ; EXIT
      CASE LS_Slovak        ; cText := "Slovak"              ; EXIT
      CASE LS_Slovenian     ; cText := "Slovenian"           ; EXIT
      CASE LS_Albanian      ; cText := "Albanian"            ; EXIT
      CASE LS_Serbian       ; cText := "Serbian"             ; EXIT
      CASE LS_Swedish       ; cText := "Swedish"             ; EXIT
      CASE LS_Swahili       ; cText := "Swahili"             ; EXIT
      CASE LS_Tamil         ; cText := "Tamil"               ; EXIT
      CASE LS_Thai          ; cText := "Thai"                ; EXIT
      CASE LS_Filipino      ; cText := "Filipino"            ; EXIT
      CASE LS_Turkish       ; cText := "Turkish"             ; EXIT
      CASE LS_Ukrainian     ; cText := "Ukrainian"           ; EXIT
      CASE LS_Urdu          ; cText := "Urdu"                ; EXIT
      CASE LS_Vietnamese    ; cText := "Vietnamese"          ; EXIT
      CASE LS_Yiddish       ; cText := "Yiddish"             ; EXIT
      CASE LS_ChineseSimp   ; cText := "Chinese Simplified"  ; EXIT
      CASE LS_ChineseTrad   ; cText := "Chinese Traditional" ; EXIT
      CASE LS_AutoDetection ; cText := "Auto-detection"      ; EXIT
    ENDSWITCH
  ENDIF

  IF lNoPrefix == .T.
    cText := HB_UTF8StrTran(cText, "&", "", 1, 1)
  ENDIF

RETURN cText
