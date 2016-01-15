/+
This file is part of GeoTool, a map viewer/editor for Lego Rock Raiders.
Copyright (C) 2014-2016  sheepandshepherd

Modified source code from dimgui: see zlib license below. <https://github.com/d-gamedev-team/dimgui>

GeoTool is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

GeoTool is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GeoTool; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
+/

/*
 * Copyright (c) 2009-2010 Mikko Mononen memon@inside.org
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */
module imgui.engine;

import std.math;
import std.stdio;
import std.string;

import imgui.api;
import imgui.gl3_renderer;

package:

/** Globals start. */

__gshared imguiGfxCmd[GFXCMD_QUEUE_SIZE] g_gfxCmdQueue;
__gshared uint g_gfxCmdQueueSize = 0;
__gshared int  g_scrollTop        = 0;
__gshared int  g_scrollBottom     = 0;
__gshared int  g_scrollRight      = 0;
__gshared int  g_scrollAreaTop    = 0;
__gshared int* g_scrollVal        = null;
__gshared int  g_focusTop         = 0;
__gshared int  g_focusBottom      = 0;
__gshared uint g_scrollId = 0;
__gshared bool g_insideScrollArea = false;
__gshared GuiState g_state;

/** Globals end. */
//import ui:buttonHeight;

enum GFXCMD_QUEUE_SIZE   = 5000;
public int BUTTON_HEIGHT       = 20;
//alias BUTTON_HEIGHT = buttonHeight;
enum SLIDER_HEIGHT       = 20;
enum SLIDER_MARKER_WIDTH = 10;
enum CHECK_SIZE          = 8;
enum DEFAULT_SPACING     = 4;
enum TEXT_HEIGHT         = 8;
enum SCROLL_AREA_PADDING = 6; //6
enum INDENT_SIZE         = 16;
enum AREA_HEADER         = 28;

// Pull render interface.
alias imguiGfxCmdType = int;
enum : imguiGfxCmdType
{
    IMGUI_GFXCMD_RECT,
    IMGUI_GFXCMD_TRIANGLE,
    IMGUI_GFXCMD_LINE,
    IMGUI_GFXCMD_TEXT,
    IMGUI_GFXCMD_SCISSOR,
	IMGUI_GFXCMD_TEXTUREDRECT,
}

struct imguiGfxRect
{
    short x, y, w, h, r;
}

struct imguiGfxTexturedRect
{
	short x, y, w, h, r;
	uint texID;
}

struct imguiGfxText
{
    short x, y, align_;
    const(char)[] text;
}

struct imguiGfxLine
{
    short x0, y0, x1, y1, r;
}

struct imguiGfxCmd
{
    char type;
    char flags;
    byte[2] pad;
    uint col;

    union
    {
        imguiGfxLine line;
        imguiGfxRect rect;
        imguiGfxText text;
		imguiGfxTexturedRect texturedRect;
    }
}

void resetGfxCmdQueue()
{
    g_gfxCmdQueueSize = 0;
}

public void addGfxCmdScissor(int x, int y, int w, int h)
{
    if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
        return;
    auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
    cmd.type   = IMGUI_GFXCMD_SCISSOR;
    cmd.flags  = x < 0 ? 0 : 1;         // on/off flag.
    cmd.col    = 0;
    cmd.rect.x = cast(short)x;
    cmd.rect.y = cast(short)y;
    cmd.rect.w = cast(short)w;
    cmd.rect.h = cast(short)h;
}

public void addGfxCmdRect(float x, float y, float w, float h, RGBA color)
{
    if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
        return;
    auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
    cmd.type   = IMGUI_GFXCMD_RECT;
    cmd.flags  = 0;
    cmd.col    = color.toPackedRGBA();
    cmd.rect.x = cast(short)(x * 8.0f);
    cmd.rect.y = cast(short)(y * 8.0f);
    cmd.rect.w = cast(short)(w * 8.0f);
    cmd.rect.h = cast(short)(h * 8.0f);
    cmd.rect.r = 0;
}

public void addGfxCmdTexturedRect(float x, float y, float w, float h, uint texID, RGBA color)
{
	if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
		return;
	auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
	cmd.type   = IMGUI_GFXCMD_TEXTUREDRECT;
	cmd.flags  = 0;
	cmd.col    = color.toPackedRGBA();
	cmd.texturedRect.x = cast(short)(x * 8.0f);
	cmd.texturedRect.y = cast(short)(y * 8.0f);
	cmd.texturedRect.w = cast(short)(w * 8.0f);
	cmd.texturedRect.h = cast(short)(h * 8.0f);
	cmd.texturedRect.r = 0;
	cmd.texturedRect.texID = texID;
}

public void addGfxCmdLine(float x0, float y0, float x1, float y1, float r, RGBA color)
{
    if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
        return;
    auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
    cmd.type    = IMGUI_GFXCMD_LINE;
    cmd.flags   = 0;
    cmd.col     = color.toPackedRGBA();
    cmd.line.x0 = cast(short)(x0 * 8.0f);
    cmd.line.y0 = cast(short)(y0 * 8.0f);
    cmd.line.x1 = cast(short)(x1 * 8.0f);
    cmd.line.y1 = cast(short)(y1 * 8.0f);
    cmd.line.r  = cast(short)(r * 8.0f);
}

public void addGfxCmdRoundedRect(float x, float y, float w, float h, float r, RGBA color)
{
    if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
        return;
    auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
    cmd.type   = IMGUI_GFXCMD_RECT;
    cmd.flags  = 0;
    cmd.col    = color.toPackedRGBA();
    cmd.rect.x = cast(short)(x * 8.0f);
    cmd.rect.y = cast(short)(y * 8.0f);
    cmd.rect.w = cast(short)(w * 8.0f);
    cmd.rect.h = cast(short)(h * 8.0f);
    cmd.rect.r = cast(short)(r * 8.0f);
}

public void addGfxCmdTriangle(int x, int y, int w, int h, int flags, RGBA color)
{
    if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
        return;
    auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
    cmd.type   = IMGUI_GFXCMD_TRIANGLE;
    cmd.flags  = cast(byte)flags;
    cmd.col    = color.toPackedRGBA();
    cmd.rect.x = cast(short)(x * 8.0f);
    cmd.rect.y = cast(short)(y * 8.0f);
    cmd.rect.w = cast(short)(w * 8.0f);
    cmd.rect.h = cast(short)(h * 8.0f);
}

public void addGfxCmdText(int x, int y, int align_, const(char)[] text, RGBA color)
{
    if (g_gfxCmdQueueSize >= GFXCMD_QUEUE_SIZE)
        return;
    auto cmd = &g_gfxCmdQueue[g_gfxCmdQueueSize++];
    cmd.type       = IMGUI_GFXCMD_TEXT;
    cmd.flags      = 0;
    cmd.col        = color.toPackedRGBA();
    cmd.text.x     = cast(short)x;
    cmd.text.y     = cast(short)y;
    cmd.text.align_ = cast(short)align_;
    cmd.text.text  = text;
}

struct GuiState
{
    bool left;
    bool leftPressed, leftReleased;
    int mx = -1, my = -1;
    int scroll;
    uint active;
    uint hot;
    uint hotToBe;
    bool isHot;
    bool isActive;
    bool wentActive;
    int dragX, dragY;
    float dragOrig;
    int widgetX, widgetY, widgetW = 100;
    bool insideCurrentScroll;

    uint areaId;
    uint widgetId;
}

bool anyActive()
{
    return g_state.active != 0;
}

bool isActive(uint id)
{
    return g_state.active == id;
}

bool isHot(uint id)
{
    return g_state.hot == id;
}

bool inRect(int x, int y, int w, int h, bool checkScroll = true)
{
    return (!checkScroll || g_state.insideCurrentScroll) && g_state.mx >= x && g_state.mx <= x + w && g_state.my >= y && g_state.my <= y + h;
}

void clearInput()
{
    g_state.leftPressed  = false;
    g_state.leftReleased = false;
    g_state.scroll       = 0;
}

void clearActive()
{
    g_state.active = 0;

    // mark all UI for this frame as processed
    clearInput();
}

void setActive(uint id)
{
    g_state.active     = id;
    g_state.wentActive = true;
}

void setHot(uint id)
{
    g_state.hotToBe = id;
}

bool buttonLogic(uint id, bool over)
{
    bool res = false;

    // process down
    if (!anyActive())
    {
        if (over)
            setHot(id);

        if (isHot(id) && g_state.leftPressed)
            setActive(id);
    }

    // if button is active, then react on left up
    if (isActive(id))
    {
        g_state.isActive = true;

        if (over)
            setHot(id);

        if (g_state.leftReleased)
        {
            if (isHot(id))
                res = true;
            clearActive();
        }
    }

    if (isHot(id))
        g_state.isHot = true;

    return res;
}

void updateInput(int mx, int my, ubyte mbut, int scroll)
{
    bool left = (mbut & MouseButton.left) != 0;

    g_state.mx = mx;
    g_state.my = my;
    g_state.leftPressed  = !g_state.left && left;
    g_state.leftReleased = g_state.left && !left;
    g_state.left         = left;

    g_state.scroll = scroll;
}

const(imguiGfxCmd*) imguiGetRenderQueue()
{
    return g_gfxCmdQueue.ptr;
}

int imguiGetRenderQueueSize()
{
    return g_gfxCmdQueueSize;
}
