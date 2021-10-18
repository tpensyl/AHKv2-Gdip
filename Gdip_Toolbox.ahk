#include Gdip_All.ahk

; Draws colored rectangle (with optional transparency)
; Use `returnValue.Destroy()` to destroy the rectangle (AHK Gui object)
FreezePicture() {
	pToken := Gdip_Startup()

	if (!pToken) {
		MsgBox "Gdiplus failed to start. Please ensure you have gdiplus on your system"
		return
	}


	static raster := 0x40000000 + 0x00CC0020 ;to capture layered windows too

    pBitmap := Gdip_BitmapFromScreen(0 "|" 0 "|" A_ScreenWidth "|" A_ScreenHeight, raster)

	Gui1 := Gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
	Gui1.Show("NA")
	hwnd1 := WinExist()

	hbm := Gdip_CreateHBITMAPFromBitmap(pBitmap)
    Gdip_DisposeImage(pBitmap)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	UpdateLayeredWindow(hwnd1, hdc, 0, 0, A_ScreenWidth, A_ScreenHeight)

	SelectObject(hdc, obm)
	DeleteObject(hbm)
	DeleteDC(hdc)
    Gdip_Shutdown(pToken)

	return Gui1
}

; Draws colored rectangle (with optional transparency)
; Use `returnValue.Destroy()` to destroy the rectangle (AHK Gui object)
DrawRectangle(x1, y1, x2, y2, color, alpha:=1) {
	pToken := Gdip_Startup()

	if (!pToken) {
		MsgBox "Gdiplus failed to start. Please ensure you have gdiplus on your system"
		return
	}

	w := x2 - x1 + 1
	h := y2 - y1 + 1
	Gui1 := Gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
	Gui1.Show("NA")
	hwnd1 := WinExist()

	hbm := CreateDIBSection(w, h)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	; Gdip_SetSmoothingMode(G, 4)
	pBrush := Gdip_BrushCreateSolid((floor(alpha * 0xFF) << 24) | color)
	Gdip_FillRectangle(G, pBrush, 0, 0, w, h)
	Gdip_DeleteBrush(pBrush)

	UpdateLayeredWindow(hwnd1, hdc, x1, y1, w, h)

	SelectObject(hdc, obm)
	DeleteObject(hbm)
	DeleteDC(hdc)
	Gdip_DeleteGraphics(G)
    Gdip_Shutdown(pToken)

	return Gui1
}

_PixelColorBufferedRefreshPeriod := 100
_PixelColorBufferedDC := 0
_isPixelColorBufferedReady := false
_shouldPixelColorBufferedWait := true


; Gets pixel color using screen buffer which refreshes on specified period (_PixelColorBufferedRefreshPeriod)
GetPixelColorBuffered(x,y) {
	global _PixelColorBufferedRefreshPeriod

	static nextUpdateTick := 0

	if (A_TickCount > nextUpdateTick) {
		_UpdateGetPixelColorBuffer(0)
		nextUpdateTick := A_TickCount + _PixelColorBufferedRefreshPeriod
	}

	return _GetPixelColorFromBuffer(x,y)
}

_GetPixelColorFromBuffer(x, y) {
	global _PixelColorBufferedDC, _isPixelColorBufferedReady, _shouldPixelColorBufferedWait
	global _PixelColorBufferedSreenLeft, _PixelColorBufferedSreenTop

	if (!IsInteger(x) || !IsInteger(y)) {
		MsgBox("Wrong parameter types: x=" x ", y=" y)
	}

	; check if there is a valid data buffer
	if (!_isPixelColorBufferedReady) {
		if (_shouldPixelColorBufferedWait) {
			Start := A_TickCount
			while (!_isPixelColorBufferedReady) {
				Sleep 10
				if (A_TickCount - Start > 5000) {   ; time out if data is not ready after 5 seconds
					return -3
				}
			}
		}
		else {
			return -2   ; return an invalid color if waiting is disabled
		}
	}
	return DllCall("GetPixel", "Uint", _PixelColorBufferedDC, "int", x - _PixelColorBufferedSreenLeft, "int", y - _PixelColorBufferedSreenTop)
}

; Default window handle is NULL (entire screen)
_UpdateGetPixelColorBuffer(windowHandle:=0) {
	global _isPixelColorBufferedReady, _PixelColorBufferedDC
	global _PixelColorBufferedSreenLeft, _PixelColorBufferedSreenTop

	static oldObject := 0, hBuffer := 0
	static screenWOld := 0, screenHOld := 0

	; get screen dimensions
	_PixelColorBufferedSreenLeft := SysGet(76)
	_PixelColorBufferedSreenTop := SysGet(77)
	screenW := SysGet(78)
	screenH := SysGet(79)
	_isPixelColorBufferedReady := 0

	; determine whether the old buffer can be reused
	bufferInvalid := screenW != screenWOld || screenH != screenHOld || _PixelColorBufferedDC == 0 || hBuffer == 0
	screenWOld := screenW
	screenHOld := screenH
	if (bufferInvalid) {
		; cleanly discard the old buffer
		DllCall("SelectObject", "Uint", _PixelColorBufferedDC, "Uint", oldObject)
		DllCall("DeleteDC", "Uint", _PixelColorBufferedDC)
		DllCall("DeleteObject", "Uint", hBuffer)

		; create a new empty buffer
		_PixelColorBufferedDC := CreateCompatibleDC(0)
		hBuffer := CreateDIBSection(screenW, screenH, _PixelColorBufferedDC)
		oldObject := DllCall("SelectObject", "Uint", _PixelColorBufferedDC, "Uint", hBuffer)
	}
	screenDC := DllCall("GetDC", "Uint", windowHandle)

	; retrieve the whole screen into the newly created buffer
	DllCall("BitBlt", "Uint", _PixelColorBufferedDC, "int", 0, "int", 0, "int", screenW, "int", screenH, "Uint", screenDC, "int", _PixelColorBufferedSreenLeft, "int", _PixelColorBufferedSreenTop, "Uint", 0x40000000 | 0x00CC0020)

	; important: release the DC of the screen
	DllCall("ReleaseDC", "Uint", windowHandle, "Uint", screenDC)
	_isPixelColorBufferedReady := 1
}
