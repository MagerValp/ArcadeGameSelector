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

Copy `AGS2`, `AGS2Helper`, `AGS2.conf`, `AGS2Background.iff`, and `Empty.iff` into `AGS:`. Copy `Startup-Sequence` to `S:` for AGS to start automatically. For each game that you wish to run create a script with the commands necessary to start it and give it a `.run` extension. You can also add a screenshot with a `.iff` extension and information with a `.txt` extension.

Place AGS:AGS2 in the Startup-Sequence after SetPatch, Assign AGS: and whatever customizations you need:

    C:SetPatch >NIL:
    C:NoClick NOCLICK
    Assign AGS: SYS:AGS
    
    AGS:AGS2
    
    ; Startup-Sequence continues here if no game is selected.


Subdirectories
--------------

Subdirectories that end with `.ags` are included at the top of the game list, and they can also have a `.iff` screenshot and a `.txt` info file. Subdirectories are currently limited to being two levels deep.


Screenshots and Colors
----------------------

The menu's screenmode, depth, palette, and colors are configurable. By default the screenmode and depth are copied from the background image, and text is rendered with the last color of the palette (255) and the second to last color (254) is used for the text's background. All of these can be configured in `AGS2.conf`. When screenshots are loaded the palette is also loaded, so to keep the screenshots from changing the colors of the user interface you can use the `lock_colors` options to lock the last colors in the palette.


Configuration
-------------

`AGS2.conf` allows you configure the following variables:

### *Background image and screen mode*
    background = AGS:AGS2Background.iff
    mode = $29000
    depth = 4
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
    text_color = 255
    text_background = 254
