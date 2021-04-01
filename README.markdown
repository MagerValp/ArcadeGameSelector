ArcadeGameSelector 2
====================

AGS2 is a joystick controlled menu program for the Amiga.


Download
--------

Downloads are available on the [releases](https://github.com/MagerValp/ArcadeGameSelector/releases) page.


Discussion and Help
-------------------

[EAB Forum Thread](http://eab.abime.net/showthread.php?t=68818)


What's New
----------

For users of version 1 a number of things have improved:

* AGA and OCS support.
* Subdirectory support, up to two levels deep.
* Configurable screen layout.
* Better control over colors.
* Screenshots are loaded in a background task, keeping the interface responsive.
* Support for screenshot slideshow.


System Requirements
-------------------

The minimum requirements for for running AGS2 are:

* 68000 CPU
* 1 MB of RAM
* OCS chipset
* Kickstart 2.0
* A hard drive or CD-ROM drive
* `iffparse.library` and `lowlevel.library`

However, games compatibility with the minimum setup will be low. The recommended minimum is:

* 68020 CPU
* 4 MB of fast RAM
* 1 MB of chip RAM
* [WHDLoad](http://www.whdload.de/)


Installation
------------

Copy `AGS2`, `AGS2Helper`, `AGS2.conf`, `AGS2Background.iff`, and `Empty.iff` into `AGS:`. Copy `Startup-Sequence` to `S:` for AGS to start automatically. For each game that you wish to run, create a script with the commands necessary to start it and give it a `.run` extension. You can also add a screenshot with a `.iff` extension and information with a `.txt` extension.

Place AGS:AGS2 in the Startup-Sequence after SetPatch, Assign AGS: and whatever customizations you need:

    C:SetPatch >NIL:
    C:NoClick NOCLICK
    Assign AGS: SYS:AGS
    
    AGS:AGS2
    
    ; Startup-Sequence continues here if no game is selected.


Usage
-----

* Joystick, gamepad, or cursor keys `Up`/`Down` to select.
* `Fire` button, CD32 `Red` button, or `Return` key to start a game or enter a directory.
* CD32 `Blue` button, `Escape` key, or `RAmiga + Q` to quit menu.


Subdirectories
--------------

Subdirectories that end with `.ags` are included at the top of the game list, and they can also have a `.iff` screenshot and a `.txt` info file. Subdirectories are currently limited to being two levels deep.


Screenshots and Colors
----------------------

The menu's screenmode, depth, palette, and colors are configurable. By default the screenmode and depth are copied from the background image, and text is rendered with the last color of the palette (255) and the second to last color (254) is used for the text's background. All of these can be configured in `AGS2.conf`. When screenshots are loaded the palette is also loaded, so to keep the screenshots from changing the colors of the user interface you can use the `lock_colors` options to lock the last colors in the palette.

AGS2 also implements a slideshow feature which allows you to use multiple screenshot images for each entry. The format to use for the filenames is `[ENTRY_NAME]-[X].iff`, where `[X]` is the numerical index (e.g. `Agony-1.iff`, `Agony-2.iff` etc). If the slidehow feature is enabled, AGS2 will look for indexed images within the configured numerical range. If no matching indexed images are found, or the slideshow feature is disabled, then it will attempt to find a file with the standard naming of `[ENTRY_NAME].iff` (e.g. `Agony.iff`). For optimum performance, it is recommended to use non-compressed (non-RLE) images if storage space is not a primary concern. Furthermore, although AGS2 can support mixed resolution screenshots, having the images in a standardized resolution will also produce the best visual results.


Configuration
-------------

`AGS2.conf` allows you configure the following variables:

### *Background image and screen mode*
    background = AGS:AGS2Background.iff
    mode = $29000
    depth = 4
    lock_colors = 4

*By default depth and mode are automatically copied from the background image, only set them if you wish to override.*

### *Font selection*
    font = topaz.font
    font_size = 8
    font_leading = 0

### *Menu layout*
    menu_x = 24
    menu_y = 8
    menu_height = 30

*The menu's width is fixed at 26 characters, plus two characters of padding. With Topaz/8 the menu is 224 pixels wide.*

### *Screenshots*
    screenshot_x = 304
    screenshot_y = 8
    empty_screenshot = AGS:Empty.iff

    # Slideshow delay in seconds
    # Set to zero to disable the slideshow feature
    slideshow_delay_secs = 3

    # Any image with an index greater than or equal to this value will be displayed
    slideshow_start_index = 1

    # Any image with an index less than or equal to this value will be displayed
    slideshow_end_index = 7

### *Information text display*
    text_x = 304
    text_y = 144
    text_width = 40
    text_height = 13
    text_color = 255
    text_background = 254

### *Miscellaneous*
    # Valid options are "quit" or "none".
    blue_button_action = quit
