ArcadeGameSelector 2
====================

AGS2 is a joystick controlled menu program for the Amiga.


What's New
----------

For users of version 1 a number of things have improved:

* AGA and OCS support.
* Subdirectory support, up to two levels deep.
* Configurable screen layout.
* Better control over colors.
* Screenshots are loaded in a background task, keeping the interface responsive.


Installation
------------

Copy `AGS2`, `AGS2Helper`, `AGS2.conf`, `AGS2Background.iff`, and `Empty.iff` into `AGS:`. Copy `Startup-Sequence` to `S:` for AGS to start automatically. For each game that you wish to run create a script with the commands necessary to start it and give it a `.run` extension. You can also add a screenshot, with a .iff extension.

When you select a game, its script is copied to `RAM:AGS.run` and AGS exits. The Startup-Sequence picks it up and executes it:

    C:SetPatch >NIL:
    Assign AGS: SYS:AGS
    
    Lab loop
    AGS:AGS2
    If EXISTS RAM:AGS.run
        Execute RAM:AGS.run
        Delete RAM:AGS.run QUIET >NIL:
        Skip loop
    EndIf
    
    ; Startup-Sequence continues here if no game is selected.


Subdirectories
--------------

Subdirectories that end with `.ags` are included at the top of the game list, and they can also have a `.iff` screenshot. Subdirectories are currently limited to being two levels deep.


Screenshots and Colors
----------------------

The menu's screenmode, depth, palette, and colors are completely configurable. By default the screenmode and depth are copied from the background image, and text is rendered with the last color of the palette (255) and the second to last color (254) is used for the text's background. All of these can be configured in `AGS2.conf`. When screenshots are loaded the palette is also loaded, so to keep the screenshots from changing the colors of the user interface you can use the `lock_colors` options to lock the last colors in the palette.

For AGA machines I would recommend designing an 8-bit background image that uses the 16 colors, leaving 240 colors to be loaded from each screenshot. For OCS machines I would recommend setting a locked palette and remapping all screenshots to use the same colors.


Configuration
-------------

`AGS2.conf` allows you configure the following variables:

### *Background image and screen mode*
    background = AGS:AGS2Background.iff
    mode = $29000
    depth = 4
    textcolor = 255
    bgcolor = 254
    lock_colors = 4

*By default depth and mode are automatically copied from the background image, only set them if you wish to override.*

### *Menu font*
    font = topaz.font
    font_size = 8

### *Position and height of the menu*
    menu_x = 24
    menu_y = 8
    menu_height = 30

### *Screenshots*
    screenshot_x = 304
    screenshot_y = 8
    empty_screenshot = AGS:Empty.iff

### *Information text position and size*
    text_x = 304
    text_y = 144
    text_width = 40
    text_height = 13
