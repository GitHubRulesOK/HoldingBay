#include "SET_COMPILE_HMG_UNICODE.ch"
#include "HMG_UNICODE.h"

#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <shlobj.h>
#include "hbapi.h"
#include "hbapierr.h"


HB_FUNC ( FILEPROPERTIES )
{
  SHELLEXECUTEINFO ExecInfo;

	ZeroMemory(&ExecInfo, sizeof(ExecInfo));

  ExecInfo.cbSize = sizeof(SHELLEXECUTEINFO);
  ExecInfo.fMask  = SEE_MASK_INVOKEIDLIST;
  ExecInfo.hwnd   = GetActiveWindow();
  ExecInfo.lpVerb = _TEXT("properties");
  ExecInfo.lpFile = HMG_parc(1);
  ExecInfo.nShow  = SW_SHOW;

  hb_retl(ShellExecuteEx(&ExecInfo));
}


       //GetLongPathName(cPath)
HB_FUNC( GETLONGPATHNAME )
{
  LPCTSTR ShortPath = (LPCTSTR) HMG_parc(1);
  TCHAR   LongPath[MAX_PATH + 1];

  if (GetLongPathName(ShortPath, LongPath, MAX_PATH + 1) > 0)
    HMG_retc(LongPath);
  else
    HMG_retc(ShortPath);
}


HB_FUNC( GETCAPTURE )
{
  HMG_retnl((LONG_PTR) GetCapture());
}


       //SetCapture(nHWnd)
HB_FUNC( SETCAPTURE )
{
  HMG_retnl((LONG_PTR) SetCapture((HWND) HMG_parnl(1)));
}


HB_FUNC( RELEASECAPTURE )
{
  hb_retl(ReleaseCapture());
}


      // TrackMouseEvent(nHWnd, [nFlags], [nHoverTime]) --> lSuccess
HB_FUNC( TRACKMOUSEEVENT )
{
  TRACKMOUSEEVENT tmi;

  tmi.cbSize      = sizeof(TRACKMOUSEEVENT);
  tmi.dwFlags     = hb_parnidef(2, TME_LEAVE);
  tmi.hwndTrack   = (HWND) HMG_parnl(1);
  tmi.dwHoverTime = hb_parnidef(3, HOVER_DEFAULT);

  hb_retl(TrackMouseEvent(&tmi));
}


       //SetCursorShape(cCursor|nCursor)
HB_FUNC( SETCURSORSHAPE )
{
  HCURSOR hCursor;

  if (HB_ISCHAR(1))
    hCursor = LoadCursor(GetModuleHandle(NULL), HMG_parc(1));
  else
    hCursor = LoadCursor(NULL, MAKEINTRESOURCE(hb_parni(1)));

  HMG_retnl((LONG_PTR) SetCursor(hCursor));
}


       //GetWindowNormalPos(nHWnd)
HB_FUNC( GETWINDOWNORMALPOS )
{
  WINDOWPLACEMENT wp;
  wp.length = sizeof(WINDOWPLACEMENT);

  GetWindowPlacement((HWND) HMG_parnl(1), &wp);

  hb_reta(4);
  hb_storvni(wp.rcNormalPosition.left,   -1, 1);
  hb_storvni(wp.rcNormalPosition.top,    -1, 2);
  hb_storvni(wp.rcNormalPosition.right,  -1, 3);
  hb_storvni(wp.rcNormalPosition.bottom, -1, 4);
}


       //SetMinMaxTrackSize(lParam, nMinX, nMinY, nMaxX, nMaxY)
HB_FUNC( SETMINMAXTRACKSIZE )
{
  MINMAXINFO *MinMax = (MINMAXINFO *) HMG_parnl(1);

  if (hb_parni(2) > 0)
    MinMax->ptMinTrackSize.x = hb_parni(2);
  if (hb_parni(3) > 0)
    MinMax->ptMinTrackSize.y = hb_parni(3);
  if (hb_parni(4) > 0)
    MinMax->ptMaxTrackSize.x = hb_parni(4);
  if (hb_parni(5) > 0)
    MinMax->ptMaxTrackSize.y = hb_parni(5);
}


       //lParam form WM_LBUTTON*, WM_MBUTTON*, WM_RBUTTON* messages
       //Tab_HitTest(nHWnd, lParam)
HB_FUNC( TAB_HITTEST )
{
  LPARAM lParam = HMG_parnl(2);
  TCHITTESTINFO tchti;

  tchti.pt.x  = (LONG) GET_X_LPARAM(lParam);
  tchti.pt.y  = (LONG) GET_Y_LPARAM(lParam);

  hb_retni(TabCtrl_HitTest((HWND) HMG_parnl(1), &tchti) + 1);
}


       //TrackPopupMenu2(nHMenu, nFlags, nRow, nCol, nHWnd)
HB_FUNC( TRACKPOPUPMENU2 )
{
  hb_retni(TrackPopupMenu((HMENU) HMG_parnl(1),
                          (UINT)  hb_parni (2),
                          (INT)   hb_parni (4),
                          (INT)   hb_parni (3),
                          0,
                          (HWND)  HMG_parnl(5),
                          NULL));
}


       //PaintSizeGrip(nHWnd)
HB_FUNC( PAINTSIZEGRIP )
{
  HWND        hWnd;
  PAINTSTRUCT ps;
  RECT        rc;
  HDC         hdc;

  hWnd = (HWND) HMG_parnl(1);
  hdc  = BeginPaint(hWnd, &ps);

  if (hdc)
  {
    GetClientRect(hWnd, &rc);

    rc.left = rc.right  - GetSystemMetrics(SM_CXVSCROLL);
    rc.top  = rc.bottom - GetSystemMetrics(SM_CYVSCROLL);

    DrawFrameControl(hdc, &rc, DFC_SCROLL, DFCS_SCROLLSIZEGRIP);
    EndPaint(hWnd, &ps);
  }
}


       //Send_WM_COPYDATA(nHWnd, nAction, cText)
HB_FUNC( SEND_WM_COPYDATA )
{
  LPTSTR         Text = (LPTSTR) HMG_parc(3);
  COPYDATASTRUCT cds;

  cds.dwData = HMG_parnl(2);
  cds.cbData = (_tcslen(Text) + 1) * sizeof(TCHAR);
  cds.lpData = Text;

  SendMessageTimeout((HWND) HMG_parnl(1), WM_COPYDATA, (WPARAM) NULL, (LPARAM) &cds, 0, 5000, NULL);
}


       //GetCopyDataAction(pCDS)
HB_FUNC( GETCOPYDATAACTION )
{
  PCOPYDATASTRUCT pCDS = (PCOPYDATASTRUCT) HMG_parnl(1);

  HMG_retnl(pCDS->dwData);
}


       //GetCopyDataString(pCDS, [lIsUTF8])
HB_FUNC( GETCOPYDATASTRING )
{
  PCOPYDATASTRUCT pCDS = (PCOPYDATASTRUCT) HMG_parnl(1);

  if (hb_parl(2))
    hb_retc(pCDS->lpData);
  else
    HMG_retc(pCDS->lpData);
}


/*
  Based on code of Dr.Claudio Soto (c_dialogs.c):
    C_GetFolder()
    BrowseCallbackProc()

  Added ability to set dialog position
*/

typedef struct
{
  TCHAR *cInitPath;
  TCHAR *cInvalidDataMsg;
  BOOL  bSetPos;
  INT   nX;
  INT   nY;
} BFFDATA;


INT CALLBACK BrowseForFolderCallback(HWND hWnd, UINT uMsg, LPARAM lParam, LPARAM lpData)
{
  // Msg :
  // BFFM_INITIALIZED   : The dialog box has finished initializing.
  // BFFM_IUNKNOWN      : An IUnknown interface is available to the dialog box.
  // BFFM_SELCHANGED    : The selection has changed in the dialog box.
  // BFFM_VALIDATEFAILED: The user typed an invalid name into the dialog's edit box. A nonexistent folder is considered an invalid name.
  //
  // SendMessage ()
  // BFFM_SETSELECTION  : Specifies the path of a folder to select. The path can be specified as a string or a PIDL.
  // BFFM_ENABLEOK      : Enables or disables the dialog box's OK button. 
  // BFFM_SETOKTEXT     : Sets the text that is displayed on the dialog box's OK button.
  // BFFM_SETEXPANDED   : Specifies the path of a folder to expand in the Browse dialog box. The path can be specified as a Unicode string or a PIDL.
  // BFFM_SETSTATUSTEXT : Sets the status text. Set the BrowseForFolderCallback lpData parameter to point to a null-terminated string with the desired text.

  TCHAR cTitle[GetWindowTextLength(hWnd) + 1];
  
  GetWindowText(hWnd, cTitle, sizeof(cTitle) / sizeof(TCHAR));

  UNREFERENCED_PARAMETER(lParam); //avoid warning message: "lParam defined but not used"

  BFFDATA *BrowseForFolderData = (BFFDATA *) lpData;

  HWND hWndNS;
  HWND hWndTV;

  switch (uMsg)
  {
    case BFFM_INITIALIZED:
      if (BrowseForFolderData->cInitPath)
        SendMessage(hWnd, BFFM_SETSELECTION, (WPARAM) TRUE, (LPARAM) BrowseForFolderData->cInitPath); 

      if (BrowseForFolderData->bSetPos)
        SetWindowPos(hWnd, NULL, BrowseForFolderData->nX, BrowseForFolderData->nY, 0, 0, SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOSIZE);

      //set focus to TreeView (Win-XP)
      //set ENSUREVISIBLE (Win-7)
      hWndNS = FindWindowEx(hWnd, NULL, _TEXT("SHBrowseForFolder ShellNameSpace Control"), NULL);

      if (hWndNS)
      {
        hWndTV = FindWindowEx(hWndNS, NULL, _TEXT("SysTreeView32"), NULL);

        if (hWndTV)
        {
          PostMessage(hWnd, WM_NEXTDLGCTL, (WPARAM) hWndTV, TRUE);
          PostMessage(hWndTV, TVM_ENSUREVISIBLE, 0, SendMessage(hWndTV, TVM_GETNEXTITEM, TVGN_CARET, 0));
        }
      }

      break;

    case BFFM_VALIDATEFAILED:
      if (BrowseForFolderData->cInvalidDataMsg)
        MessageBox(hWnd, BrowseForFolderData->cInvalidDataMsg, cTitle, MB_ICONHAND | MB_OK | MB_SYSTEMMODAL); //(TCHAR *)lParam ---> cFolderName
      else
        MessageBeep(MB_ICONHAND);           

      return 1;
  }

  return 0;
}


       //                 1         2         3                    4                    5            6       7
       //BrowseForFolder([cTitle], [nFlags], [nCSIDL_FolderType], [cInvalidDataTitle], [cInitPath], [nRow], [nCol])
HB_FUNC( BROWSEFORFOLDER )
{
  HWND         hWnd = GetActiveWindow();
  BROWSEINFO   BrowseInfo;
  TCHAR        cBuffer[MAX_PATH];
  LPITEMIDLIST ItemIDList;

  SHGetSpecialFolderLocation(hWnd, HB_ISNIL(3) ? CSIDL_DRIVES : hb_parnl(3), &ItemIDList);

  // BrowseInfo.ulFlags
  // ------------------
  // BIF_RETURNONLYFSDIRS   : Only return file system directories.
  // BIF_DONTGOBELOWDOMAIN  : Do not include network folders below the domain level in the dialog box's tree view control.
  // BIF_STATUSTEXT         : Include a status area in the dialog box ( not supported when BIF_NEWDIALOGSTYLE )
  // BIF_RETURNFSANCESTORS  : Only return file system ancestors. An ancestor is a subfolder that is beneath the root folder in the namespace hierarchy.
  // BIF_EDITBOX            : Include an edit control in the browse dialog box that allows the user to type the name of an item.
  // BIF_VALIDATE           : If the user types an invalid name into the edit box, the browse dialog box calls the application's BrowseForFolderCallback 
  //                          with the BFFM_VALIDATEFAILED message ( ignored if BIF_EDITBOX is not specified)
  // BIF_NEWDIALOGSTYLE     : Use the new user interface. Setting this flag provides the user with a larger dialog box that can be resized. 
  //                          The dialog box has several new capabilities, including: drag-and-drop capability within the dialog box, 
  //                          reordering, shortcut menus, new folders, delete, and other shortcut menu commands.
  // BIF_BROWSEINCLUDEURLS  : The browse dialog box can display URLs. The BIF_USENEWUI and BIF_BROWSEINCLUDEFILES flags must also be set.
  // BIF_USENEWUI           : equivalent to BIF_EDITBOX + BIF_NEWDIALOGSTYLE.
  // BIF_UAHINT             : When combined with BIF_NEWDIALOGSTYLE, adds a usage hint to the dialog box, in place of the edit box (BIF_EDITBOX overrides this flag)
  // BIF_NONEWFOLDERBUTTON  : Do not include the New Folder button in the browse dialog box.
  // BIF_NOTRANSLATETARGETS : When the selected item is a shortcut, return the PIDL of the shortcut itself rather than its target.
  // BIF_BROWSEFORCOMPUTER  : Only return computers
  // BIF_BROWSEFORPRINTER   : Only allow the selection of printers. In Windows XP and later systems, the best practice is to use a Windows XP-style dialog, 
  //                          setting the root of the dialog to the Printers and Faxes folder (CSIDL_PRINTERS).
  // BIF_BROWSEINCLUDEFILES : The browse dialog box displays files as well as folders.
  // BIF_SHAREABLE          : The browse dialog box can display sharable resources on remote systems. The BIF_NEWDIALOGSTYLE flag must also be set.
  // BIF_BROWSEFILEJUNCTIONS: Windows 7 and later. Allow folder junctions such as a library or a compressed file with a .zip file name extension to be browsed.

  BFFDATA BrowseForFolderData;

  BrowseForFolderData.cInvalidDataMsg = (TCHAR *) HMG_parc(4);
  BrowseForFolderData.cInitPath       = (TCHAR *) HMG_parc(5);

  if (HB_ISNUM(6) && HB_ISNUM(7))
  {
    BrowseForFolderData.bSetPos = TRUE;
    BrowseForFolderData.nX      = hb_parni(7);
    BrowseForFolderData.nY      = hb_parni(6);
  }
  else
    BrowseForFolderData.bSetPos = FALSE;

  BrowseInfo.hwndOwner      = hWnd;
  BrowseInfo.pidlRoot       = ItemIDList;
  BrowseInfo.pszDisplayName = cBuffer;
  BrowseInfo.lpszTitle      = HMG_parc(1);
  BrowseInfo.ulFlags        = hb_parnl(2);
  BrowseInfo.lpfn           = BrowseForFolderCallback;
  BrowseInfo.lParam         = (LPARAM) &BrowseForFolderData;
  BrowseInfo.iImage         = 0;
  
  ItemIDList = SHBrowseForFolder(&BrowseInfo);

  if (ItemIDList)
  {
    SHGetPathFromIDList(ItemIDList, cBuffer);
    HMG_retc(cBuffer);
  }
  else
    HMG_retc(_TEXT(""));

  CoTaskMemFree((LPVOID) ItemIDList); // It is the responsibility of the calling application to call CoTaskMemFree to free the IDList returned 
                                      // by SHBrowseForFolder when it is no longer needed.
}


/*
  adapted from tip_URLEncode()
*/
       //EncodeURIComponent(cText)
HB_FUNC( ENCODEURICOMPONENT )
{
  const char * pszData = hb_parc(1);

  if (pszData)
  {
    HB_ISIZ nLen = hb_parclen(1);

    if (nLen)
    {
      HB_ISIZ nPos = 0, nPosRet = 0;

      /*Giving maximum final length possible*/
      char * pszRet = (char *) hb_xgrab(nLen * 3 + 1);
      char cElem;
      HB_UINT uiVal;

      while (nPos < nLen)
      {
        cElem = pszData[nPos];

        if ((cElem >= 'A' && cElem <= 'Z') ||
            (cElem >= 'a' && cElem <= 'z') ||
            (cElem >= '0' && cElem <= '9') ||
            cElem == '-' || cElem == '_' || cElem == '.' || cElem == '!' || cElem == '~' || cElem == '*' || cElem == '\'' || cElem == '(' || cElem == ')')
        {
          pszRet[nPosRet] = cElem;
        }
        else /*encode*/
        {
          pszRet[nPosRet++] = '%';
          uiVal = ((HB_UCHAR) cElem) >> 4;
          pszRet[nPosRet++] = (char) ((uiVal < 10 ? '0' : 'A' - 10) + uiVal);
          uiVal = ((HB_UCHAR) cElem) & 0x0F;
          pszRet[nPosRet] = (char) ((uiVal < 10 ? '0' : 'A' - 10) + uiVal);
        }

        nPosRet++;
        nPos++;
      }

      hb_retclen_buffer(pszRet, nPosRet);
    }
    else
      hb_retc_null();
  }
  else
    hb_errRT_BASE(EG_ARG, 3012, NULL, HB_ERR_FUNCNAME, 1, hb_paramError(1));
}
