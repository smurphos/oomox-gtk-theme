#!/bin/bash

#
# (C) 2017 actionless
#

set -ueo pipefail

DEFAULT_SLEEP=${DEFAULT_SLEEP:-2}
TEST_DIR=$(readlink -e $(dirname "${0}"))
TEST_RESULT_DIR=${TEST_DIR}/../test_results/
SCREENSHOTS_DIR=${TEST_DIR}/../screenshots/
mkdir -p ${TEST_RESULT_DIR} || true
cd ${TEST_DIR}


#THEME_NAME=${THEME_NAME:-monovedek}
#GTK2_RESOLUTION=${GTK2_RESOLUTION:-630x560x16}
#GTK2_AWF_RESOLUTION=${GTK2_AWF_RESOLUTION:-840x700x16}
#GTK3_RESOLUTION=${GTK3_RESOLUTION:-1280x720x16}
#FONT_SIZE=${FONT_SIZE:-10}

if [[ "${TEST_HIDPI:-}" -eq 1 ]] ; then
	export GDK_SCALE=2
	export GDK_DPI_SCALE=0.5

	export GTK2_RESOLUTION="1260x1120x16"
	export GTK2_AWF_RESOLUTION="1680x1400x16"
	export GTK3_RESOLUTION="2480x1500x16"
	export FONT_SIZE="20"
else
	export GDK_SCALE=1
	export GDK_DPI_SCALE=1

	export GTK2_RESOLUTION="630x560x16"
	export GTK2_AWF_RESOLUTION="840x700x16"
	export GTK3_RESOLUTION="1240x750x16"
	export FONT_SIZE="10"
fi


TEST_EXIT_CODE=0

mkdir -p ~/.config/gtk-3.0 || true
mkdir -p ~/.config/openbox || true

sed \
	-e 's/\${THEME_NAME}/'${THEME_NAME}'/g' \
	-e 's/\${FONT_SIZE}/'${FONT_SIZE}'/g' \
	./gtk3-settings.ini.tpl > ~/.config/gtk-3.0/settings.ini
sed \
	-e 's/\${THEME_NAME}/'${THEME_NAME}'/g' \
	-e 's/\${FONT_SIZE}/'${FONT_SIZE}'/g' \
	./openbox-rc.xml.tpl > ~/.config/openbox/rc.xml
sed \
	-e 's/\${THEME_NAME}/'${THEME_NAME}'/g' \
	-e 's/\${FONT_SIZE}/'${FONT_SIZE}'/g' \
	./gtkrc-2.0.tpl > ~/.gtkrc-2.0


killall Xvfb 2>/dev/null || true
killall openbox 2>/dev/null || true
killall lxappearance 2>/dev/null || true

_kill_procs() {
	set +e
	if [[ ! -z ${compare_output:-} ]] ; then
		rm ${compare_output:-} || true
	fi
	kill -TERM $opbx || true
	wait $opbx
	kill -TERM $xvfb || true
	wait $xvfb
}
trap _kill_procs EXIT SIGHUP SIGINT SIGTERM INT

################################################################################
start_xserver_and_wm() {
	resolution=${1}
	Xvfb :99 -ac -screen 0 $resolution -nolisten tcp &
	xvfb=$!
	echo "== Started Xvfb"
	export DISPLAY=:99
	sleep ${DEFAULT_SLEEP}
	openbox &
	opbx=$!
	echo "== Started openbox"
	sleep ${DEFAULT_SLEEP}
	xrdb -merge ./Xresources
	xsetroot -solid white
	xdotool mousemove --sync 0 0
	#sleep ${DEFAULT_SLEEP}
}

get_window_id() {
	xdotool search --pid $1 2>/dev/null | tail -n 1
}

make_and_compare_screenshot() {
	test_variant=${1}
	sleep ${DEFAULT_SLEEP}
	screenshot_base_name=theme-${THEME_NAME}-${test_variant}
	test_result_base_name=$(date +%Y-%m-%d_%H-%M-%S)_${screenshot_base_name}
	scrot ${TEST_RESULT_DIR}/${test_result_base_name}.test.png
	compare -verbose -metric PAE \
		${SCREENSHOTS_DIR}/${screenshot_base_name}.png \
		${TEST_RESULT_DIR}/${test_result_base_name}.test.png \
		${TEST_RESULT_DIR}/${test_result_base_name}.diff.png \
		|| true
	compare_result=0
	compare_output=$(mktemp)
	compare -verbose -metric AE -fuzz 1 \
		${SCREENSHOTS_DIR}/${screenshot_base_name}.png \
		${TEST_RESULT_DIR}/${test_result_base_name}.test.png \
		${TEST_RESULT_DIR}/${test_result_base_name}.diff.png \
		1>${compare_output} 2>&1 \
		|| compare_result=$?
	if [[ ${compare_result} -eq 0 ]] ; then
		echo
		echo "!!! SUCCESS"
		rm ${TEST_RESULT_DIR}/${test_result_base_name}.test.png
		rm ${TEST_RESULT_DIR}/${test_result_base_name}.diff.png
		echo
	else
		echo
		echo "[X] FAIL"
		echo
		cat ${compare_output}
		echo
		if [[ -z ${GENERATE_ASSETS:-} ]] ; then
			curl --upload-file ${TEST_RESULT_DIR}/${test_result_base_name}.test.png \
				https://transfer.sh/${test_result_base_name}.test.png >> ${TEST_RESULT_DIR}/links.txt \
				&& echo >> ${TEST_RESULT_DIR}/links.txt \
				|| true
			curl --upload-file ${SCREENSHOTS_DIR}/${screenshot_base_name}.png \
				https://transfer.sh/${test_result_base_name}.orig.png >> ${TEST_RESULT_DIR}/links.txt \
				&& echo >> ${TEST_RESULT_DIR}/links.txt \
				|| true
			curl --upload-file ${TEST_RESULT_DIR}/${test_result_base_name}.diff.png \
				https://transfer.sh/${test_result_base_name}.diff.png >> ${TEST_RESULT_DIR}/links.txt \
				&& echo >> ${TEST_RESULT_DIR}/links.txt \
				|| true
			exit 1
		else
			cp ${TEST_RESULT_DIR}/${test_result_base_name}.test.png \
				${SCREENSHOTS_DIR}/${screenshot_base_name}.png
		fi
		TEST_EXIT_CODE=1
	fi
}
################################################################################


#echo
#echo "========= Going to generate ${THEME_NAME} theme..."
#theme_gen_log="./theme-gen-${THEME_NAME}.log"
#bash /opt/oomox-gtk-theme/change_color.sh /opt/oomox-gtk-theme/test/colors/${THEME_NAME} >${theme_gen_log} 2>&1 &
#oomox_pid=$!

#wait $oomox_pid
#echo "== Theme generated successfully"


#echo
#echo "========= Going to test GTK+2 theme..."
#echo
#start_xserver_and_wm ${GTK2_RESOLUTION}
#sleep ${DEFAULT_SLEEP}
#lxappearance 1>/dev/null 2>&1 &
#echo "== Started lxaappearance"
#make_and_compare_screenshot "gtk2"
#_kill_procs


################################################################################
echo
echo "========= Going to test GTK+2 theme (awf)..."
echo

start_xserver_and_wm ${GTK2_AWF_RESOLUTION}

FAKETIME="2017-08-29 01:02:01" FAKETIME_NO_CACHE=1 LD_PRELOAD=/usr/lib/faketime/libfaketime.so.1 awf-gtk2 2>/dev/null &
echo "== Started awf-gtk2"

make_and_compare_screenshot "gtk2-awf"

################################################################################
_kill_procs
echo
echo "========= Going to test GTK+3 theme..."
echo

start_xserver_and_wm ${GTK3_RESOLUTION}

echo "== Page 1"
echo
sleep ${DEFAULT_SLEEP}
sleep ${DEFAULT_SLEEP}
FAKETIME="2017-08-29 01:02:03" FAKETIME_NO_CACHE=1 LD_PRELOAD=/usr/lib/faketime/libfaketime.so.1 gtk3-widget-factory 2>/dev/null &
gwf=$!
echo "== Started gtk3-widget-factory"
sleep ${DEFAULT_SLEEP}
sleep ${DEFAULT_SLEEP}
make_and_compare_screenshot "gtk3-page1"
kill $gwf
wait $gwf
echo "== Killed gtk-widget-factory"

echo "== Page 2"
echo
sleep ${DEFAULT_SLEEP}
FAKETIME="@2017-08-29 01:03:04" FAKETIME_NO_CACHE=1 LD_PRELOAD=/usr/lib/faketime/libfaketime.so.1 gtk3-widget-factory 2>/dev/null &
gwf=$!
echo "== Started gtk3-widget-factory"

sleep ${DEFAULT_SLEEP}
if [[ "${TEST_HIDPI:-}" -eq 1 ]] ; then
	X=1240
	Y=60
else
	X=620
	Y=30
fi
xdotool mousemove -w $(get_window_id $gwf) --sync $X $Y
xdotool click 1
xdotool mousemove --sync 0 0
make_and_compare_screenshot "gtk3-page2"

echo "== Page 3"
if [[ "${TEST_HIDPI:-}" -eq 1 ]] ; then
	X=1440
	Y=60
else
	X=720
	Y=30
fi
xdotool mousemove -w $(get_window_id $gwf) --sync $X $Y
xdotool click 1
xdotool mousemove --sync 0 0
make_and_compare_screenshot "gtk3-page3"


exit ${TEST_EXIT_CODE}
