#!/bin/zsh

# XcodeNueve: Modify Xcode 9.4.1's toolchain to run on 10.15+

# If run without arguments, will prompt for path to Xcode and signing identity to use
# To run non-interactively, pass Xcode path as 1st argument and signing identity 2nd.

check_file_exists() {
    if [ ! -f "$1" ]; then
        echo "$0: $1 missing"
        exit 1
    fi
}

check_sha256() {
    if [ `openssl dgst -sha256 "$1" | sed 's/SHA256(.*)= //'` != "$2" ]; then
        echo "$0: $1 has an unexpected checksum. Is this an unmodified copy of Xcode 9.4.1?"
        exit 1
    fi
}

remove_dir_if_exists() {
    if [ -d "$1" ]; then
        rm -rf "$1"
    fi
}

PNGCRUSH_URL="https://altushost-swe.dl.sourceforge.net/project/pmt/pngcrush/1.8.13/pngcrush-1.8.13.zip"
PYTHON_URL="https://www.python.org/ftp/python/2.7.18/python-2.7.18-macosx10.9.pkg"

XCODE="/Applications/Xcode9.app"
IDENTITY="XcodeSigner"

if [ "$#" -eq 0 ]; then
    # Running interactively, prompt for Xcode path and signing identity
    echo "XcodeNueve 🛠 9️⃣ : patch Xcode 9.4.1 to run on 10.15+\n"

    if [ -f "$PWD/Xcode9.app/Contents/Info.plist" ]; then
        XCODE="$PWD/Xcode9.app"
    fi

    read -p "Path to Xcode 9.4.1 [$XCODE]: " TMPINPUT
    if [ ! -z "$TMPINPUT" ]; then
        XCODE="$TMPINPUT"
    fi

    read -p "Signing identity to use [$IDENTITY]: " TMPINPUT
    if [ ! -z "$TMPINPUT" ]; then
        IDENTITY="$TMPINPUT"
    fi
elif [ "$#" -eq 2 ]; then
    # Two arguments given: Xcode path and signing identity
    XCODE="$1"
    IDENTITY="$2"
else
    echo "usage: $0 <path to Xcode 9.4.1> <signing identity to use>"
    exit 1
fi

check_file_exists "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"
check_file_exists "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"

check_sha256 "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit" \
             "06db61b1de8b7242de20248a7a9a829edcec43ee77190d02a9bda57192b45251"

check_sha256 "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit" \
             "c8d45ddd9e1334554cc57ee9bb1bc437920f599710aa81b1cbe144fa7ee59740"

# Do a test codesign to check that the given identity exists before we start modifying files
codesign --dryrun -f -s $IDENTITY "$XCODE/Contents/Developer/usr/bin/xcodebuild"

# Change reference in DVTKit from _OBJC_IVAR_$_NSFont._fFlags to _OBJC_IVAR_$_NSCell._cFlags
echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x478967 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Change reference in DVTKit from _OBJC_IVAR_$_NSUndoTextOperation._layoutManager to _OBJC_IVAR_$_NSUndoTextOperation._affectedRange
echo "61666665 63746564 52616E67 65" | xxd -r -p -s 0x478ab6 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Change references in IDEInterfaceBuilderKit from _OBJC_IVAR_$_NSFont._fFlags to _OBJC_IVAR_$_NSCell._cFlags
echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x7bed6d - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"
echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x899801 - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"

# Change references from _OBJC_IVAR_$_NSTableView._reserved to _OBJC_IVAR_$_NSTableView._delegate
echo "64656C65 67617465" |  xxd -r -p -s 0x7bee08 - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"
echo "64656C65 67617465" |  xxd -r -p -s 0x899894 - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"

# Fix -[DVTSearchFieldCell willDrawVibrantly] method of DVTKit that crashes the whole UI
echo "66909066 90906690 90" |  xxd -r -p -s 0xB63AE - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Fix build/clean/test/etc square alerts in -[DVTBezelAlertPanel effectViewForBezel] (uses undocumented & outdated method)
echo "66906690 669090" |  xxd -r -p -s 0xD0E40 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"
echo "66909066 9090" |  xxd -r -p -s 0xD0EA1 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Copy libtool from the (presumably newer) installed Xcode.app, to fix crashes on Monterey
if [ -f "`xcode-select -p`/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" ]; then
    cp -p "`xcode-select -p`/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" "$XCODE/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool"
else
    if [ -f "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" ]; then
        cp -p "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" "$XCODE/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool"
    else
        echo "$0: Unable to find another Xcode to copy libtool from. Beware, Xcode 9.4.1's libtool sometimes crashes on Monterey."
    fi
fi

python2_install() {
    echo "Downloading Python 2.7.18..." 
    # Download Python 2.7.18 installer to use a part of it for making a working dependency
    local python_tmp_dir="$TMPDIR/python2.7-installer"
    local python_install_dir="/Library/Frameworks/Python.framework/"
    # Delete previous temp dir if it exists
    remove_dir_if_exists "$python_tmp_dir"
    mkdir $python_tmp_dir
    curl -o "$python_tmp_dir/python2.pkg" "$PYTHON_URL"
    if ! [ $? = 0 ]; then
        echo "❌  Something went wrong during downloading Python archive."
        return 1
    fi
    xar -C $python_tmp_dir -xf "$python_tmp_dir/python2.pkg"
    if [ -d "/Library/Frameworks/Python.framework/" ]; then
        # If some Python version is alreary installed,
        # we copy Python 2.7 files to Python.framework/Versions/2.7/
        python_install_dir="/Library/Frameworks/Python.framework/Versions/2.7/"
        payload_extracted="$python_tmp_dir/Python_Framework.pkg/Payload/extracted"
        mkdir "$payload_extracted"
        tar xvf "$python_tmp_dir/Python_Framework.pkg/Payload" -C "$payload_extracted" &> /dev/null
        sudo -- zsh -c <<EOF
        mkdir "$python_install_dir"
        mv "$payload_extracted/Versions/2.7/*" "$python_install_dir"
EOF
        if ! [ $? = 0 ]; then
            echo "❌  Something went wrong during installing Python 2."
            return 1
        fi
        echo "✅  Python 2 Framework is successfully installed"
    else
        # If Python isn't installed,
        # we copy all Python 2.7 files to Python.framework
        sudo -- zsh -c <<EOF
        mkdir "$python_install_dir"
        tar xvf "$python_tmp_dir/Python_Framework.pkg/Payload" -C $python_install_dir &> /dev/null
EOF
    fi
    if ! [ $? = 0 ]; then
        echo "❌  Something went wrong during installing Python 2."
        return 1
    fi
    remove_dir_if_exists "$python_tmp_dir" # remove temp dir
    return 0
}

python2() {
    # Building Python 2 from sources and patching Xcode's executables
    # to work with a local copy of it would've solve this problem.
    # But building it is really painful on modern macOSs so it's easier to
    # just download it and put inside of /Library/Frameworks/Python.framework/ directory.
    echo "❓ Do you want to install Python 2 Framework?"
    echo "Doing that will likely decrease your system security \
    because Python 2 is not being maintainted since 2020. If you don't install it, \
    Xcode 9 UI and ipatool (may be needed to build iOS apps) won't work. \
    To make build tools work LLDB.framework and DebuggerLLDB.ideplugin will be deleted. \n\
    If you choose to install, don't forget to delete it when you're done \
    (/Library/Frameworks/Python.framework/Versions/2.7/)."
    echo "1️⃣  Install Python 2 Framework (root privilages might be required)"
    echo "2️⃣  Don't install Python 2 Framework"

    local result=0
    while :
    do 
        read "python2_user_choise?Choise: "
        if [ "$python2_user_choise" = "1" ]; then
            python2_install
            result=$?
            break
        fi
        if [ "$python2_user_choise" = "2" ]; then
            # Delete components depending on Python 2 to make build tools work
            rm -rf "$XCODE/Contents/PlugIns/DebuggerLLDB.ideplugin"
            rm -rf "$XCODE/Contents/SharedFrameworks/LLDB.framework"
            result=0
            break
        fi
    done
    return "$result"
}

if [ -d "/Library/Frameworks/Python.framework/Versions/2.7" ]; then
    echo "✅  Python 2 Framework is already installed"
else
    while :
    do
        python2
        install_result=$?
        while ! [ install_result = 0 ]:
        do 
            echo "❌  Python 2 installation failed. Do you want to try again? (y/n)"
            read "python2_install_again?Choise: "
            if [ "$python2_install_again" = "y" ]
                python2
                install_result=$?
            fi
            if [ "$python2_install_again" = "n" ]
                install_result=0
            fi
    done
fi

# Replace old pngcrush util (i386 only) with a new version (x86_64)
# by compiling it from sources
replace_pngcrush() {
    local pngcrush_tmp_dir="$TMPDIR/pngcrush-sources"
    local pngcrush_tmp_zip="$pngcrush_tmp_dir/pngcrush.zip"
    local pngcrush_extracted_zip="$pngcrush_tmp_dir/extracted/"
    local result=0
    # Delete previous temp dir if it exists
    remove_dir_if_exists "$pngcrush_tmp_dir"
    mkdir "$pngcrush_tmp_dir"
    curl -o "$pngcrush_tmp_zip" "$PNGCRUSH_URL"
    if ! [ $? = 0 ]; then
        echo "❌  Something went wrong during downloading pngcrush sources."
        return 1
    fi
    mkdir "$pngcrush_tmp_dir/extracted" 
    unzip "$pngcrush_tmp_zip" -d "$pngcrush_extracted_zip"
    arch -x86_64 make -C "$pngcrush_extracted_zip/pcr010813/"
    if [ -f "$pngcrush_extracted_zip/pcr010813/pngcrush" ]; then
        cp -p "$pngcrush_extracted_zip/pcr010813/pngcrush" "$XCODE/Contents/Developer/usr/bin/pngcrush"
        cp -p "$pngcrush_extracted_zip/pcr010813/pngcrush" "$XCODE/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/pngcrush"
        chmod +x "$XCODE/Contents/Developer/usr/bin/pngcrush"
        chmod +x "$XCODE/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/pngcrush"
        echo "✅  Pngcrush has been successfully compiled and replaced"
        result=0
    else
        echo "❌  Something went wrong during compiling pngcrush sources"
        result=1
    fi
    remove_dir_if_exists "$pngcrush_tmp_dir"
    return "$result"
}

# Copy pngcrush from the (presumably newer) installed Xcode.app
if [ -f "`xcode-select -p`/usr/bin/pngcrush" ]; then
    cp -p "`xcode-select -p`/usr/bin/pngcrush" "$XCODE/Contents/Developer/usr/bin/pngcrush"
else
    if [ -f "/Applications/Xcode.app/Contents/Developer/usr/bin/pngcrush" ]; then
        cp -p "/Applications/Xcode.app/Contents/Developer/usr/bin/pngcrush" "$XCODE/Contents/Developer/usr/bin/pngcrush"
        echo "✅  Pngcrush has been replaced with a version from a newer Xcode"
    else
        echo "❌  Unable to find another Xcode to copy pngcrush from. Trying to download and compile it from sources..."
        while :
        do
            replace_pngcrush
            install_result=$?
            while ! [ install_result = 0 ]:
            do 
                echo "❌  Pngcrush installation failed. Do you want to try again? (y/n)"
                read "pngcrush_install_again?Choise: "
                if [ "$pngcrush_install_again" = "y" ]
                    replace_pngcrush
                    install_result=$?
                fi
                if [ "$pngcrush_install_again" = "n" ]
                    install_result=0
                fi
        done
    fi
fi

codesign -f -s $IDENTITY "$XCODE/Contents/SharedFrameworks/DVTKit.framework"
codesign -f -s $IDENTITY "$XCODE"
codesign -f -s $IDENTITY "$XCODE/Contents/SharedFrameworks/DVTDocumentation.framework"
codesign -f -s $IDENTITY "$XCODE/Contents/Frameworks/IDEFoundation.framework"
codesign -f -s $IDENTITY "$XCODE/Contents/Developer/usr/bin/xcodebuild"
codesign -f -s $IDENTITY "$XCODE/Contents/SharedFrameworks/LLDB.framework"
