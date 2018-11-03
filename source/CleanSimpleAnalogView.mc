using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Application;

var partialUpdatesAllowed = false;

// This implements an analog watch face
// Original design by Austen Harbour
class CleanSimpleAnalogView extends WatchUi.WatchFace {
    var font;
    var isAwake;
    var screenShape;
    var dndIcon;
    var offscreenBuffer;
    var dateBuffer;
    var curClip;
    var screenCenterPoint;
    var fullScreenRefresh;

    // Initialize variables for this view
    function initialize() {
        WatchFace.initialize();
        screenShape = System.getDeviceSettings().screenShape;
        fullScreenRefresh = true;
        partialUpdatesAllowed = ( Toybox.WatchUi.WatchFace has :onPartialUpdate );
    }

    // Configure the layout of the watchface for this device
    function onLayout(deviceContext) {

        // Load the custom font we use for drawing the 3, 6, 9, and 12 on the watchface.
        font = WatchUi.loadResource(Rez.Fonts.id_font_fenix_font);

        // If this device supports the Do Not Disturb feature,
        // load the associated Icon into memory.
        if (System.getDeviceSettings() has :doNotDisturb) {
            dndIcon = WatchUi.loadResource(Rez.Drawables.DoNotDisturbIcon);
        } else {
            dndIcon = null;
        }

        // If this device supports BufferedBitmap, allocate the buffers we use for drawing
        if(Toybox.Graphics has :BufferedBitmap) {
            // Allocate a full screen size buffer with a palette of only 4 colors to draw
            // the background image of the watchface.  This is used to facilitate blanking
            // the second hand during partial updates of the display
            offscreenBuffer = new Graphics.BufferedBitmap({
                :width=>deviceContext.getWidth(),
                :height=>deviceContext.getHeight(),
                :palette=> [
                    Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE
                ]
            });

            // Allocate a buffer tall enough to draw the date into the full width of the
            // screen. This buffer is also used for blanking the second hand. This full
            // color buffer is needed because anti-aliased fonts cannot be drawn into
            // a buffer with a reduced color palette
            dateBuffer = new Graphics.BufferedBitmap({
                :width=>deviceContext.getWidth(),
                :height=>Graphics.getFontHeight(Graphics.FONT_MEDIUM)
            });
        } else {
            offscreenBuffer = null;
        }

        curClip = null;

        screenCenterPoint = [deviceContext.getWidth()/2, deviceContext.getHeight()/2];
    }

    // This function is used to generate the coordinates of the 4 corners of the polygon
    // used to draw a watch hand. The coordinates are generated with specified length,
    // tail length, and width and rotated around the center point at the provided angle.
    // 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    function generateHandCoordinates(centerPoint, angle, handLength, tailLength, width) {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength], [-(width / 2), -handLength], [width / 2, -handLength], [width / 2, tailLength]];
        var result = new [4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i += 1) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }

    // Draws the clock tick marks around the outside edges of the screen.
    function drawHashMarks(deviceContext) {
        deviceContext.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        var width = deviceContext.getWidth();
        var height = deviceContext.getHeight();

        // Draw hashmarks differently depending on screen geometry.
        if (System.SCREEN_SHAPE_ROUND == screenShape) {
            var sX, sY;
            var eX, eY;
            var outerRad = width / 2;
            var innerRad = outerRad - 5;	// length of hashmark
            // Loop through each 15 minute block and draw tick marks.
            for (var i = Math.PI / 6; i <= 11 * Math.PI / 6; i += (Math.PI / 3)) {
                // Partially unrolled loop to draw two tickmarks in 15 minute block.
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                deviceContext.drawLine(sX, sY, eX, eY);
                i += Math.PI / 6;
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                deviceContext.drawLine(sX, sY, eX, eY);
            }
        } else {
            var coords = [0, width / 4, (3 * width) / 4, width];
            for (var i = 0; i < coords.size(); i += 1) {
                var dx = ((width / 2.0) - coords[i]) / (height / 2.0);
                var upperX = coords[i] + (dx * 10);
                // Draw the upper hash marks.
                deviceContext.fillPolygon([[coords[i] - 1, 2], [upperX - 1, 12], [upperX + 1, 12], [coords[i] + 1, 2]]);
                // Draw the lower hash marks.
                deviceContext.fillPolygon([[coords[i] - 1, height-2], [upperX - 1, height - 12], [upperX + 1, height - 12], [coords[i] + 1, height - 2]]);
            }
        }
    }

    // Handle the update event
    function onUpdate(deviceContext) {
        var width;
        var height;
        var screenWidth = deviceContext.getWidth();
        var clockTime = System.getClockTime();
        var minuteHandAngle;
        var hourHandAngle;
        var secondHand;
        var targetDeviceContext = null;

        // We always want to refresh the full screen when we get a regular onUpdate call.
        fullScreenRefresh = true;

        if(null != offscreenBuffer) {
            deviceContext.clearClip();
            curClip = null;
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDeviceContext = offscreenBuffer.getDc();
        } else {
            targetDeviceContext = deviceContext;
        }

        width = targetDeviceContext.getWidth();
        height = targetDeviceContext.getHeight();

        // Fill the entire background with Black.
        targetDeviceContext.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        targetDeviceContext.fillRectangle(0, 0, deviceContext.getWidth(), deviceContext.getHeight());


        // Draw the tick marks around the edges of the screen
        drawHashMarks(targetDeviceContext);

        // Draw the do-not-disturb icon if we support it and the setting is enabled
        if (null != dndIcon && System.getDeviceSettings().doNotDisturb) {
            targetDeviceContext.drawBitmap( width * 0.75, height / 2 - 15, dndIcon);
        }

        // Use white
        targetDeviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Draw the 3, 6, 9, and 12 hour labels.
        targetDeviceContext.drawText((width / 2), 0, font, "12", Graphics.TEXT_JUSTIFY_CENTER);
        targetDeviceContext.drawText(width - 2, (height / 2)+2, font, "3", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        targetDeviceContext.drawText(width / 2, height-25, font, "6", Graphics.TEXT_JUSTIFY_CENTER);
        targetDeviceContext.drawText(2, (height / 2)+2, font, "9", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // If we have an offscreen buffer that we are using for the date string,
        // Draw the date into it. If we do not, the date will get drawn every update
        // after blanking the second hand.
/*        if( null != dateBuffer ) {
            var dateDc = dateBuffer.getDc();

            //Draw the background image buffer into the date buffer to set the background
            dateDc.drawBitmap(0, -(height / 4), offscreenBuffer);

            //Draw the date string into the buffer.
            drawDateString( dateDc, width / 2, 0 );
        }*/

		var isBluetoothConnected= System.getDeviceSettings().phoneConnected;
		var notificationCount = System.getDeviceSettings().notificationCount;
		var bluetoothConnectedLocation = width/2;
		var notificationCountLocation = width/2;
		var bluetoothJustification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
		var notificationJustification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
		if( isBluetoothConnected && notificationCount > 0 ) {
			bluetoothConnectedLocation = width/2 - 30;
			notificationCountLocation = width/2 + 30;
			bluetoothJustification = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
			notificationJustification = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
		}			

        // Output the offscreen buffers to the main display if required (includes date)
        drawBackground(deviceContext);

		if( isBluetoothConnected ) {
	        // Draw bluetooth connected indicator directly to the main screen.
	        deviceContext.drawText(bluetoothConnectedLocation, 55, font, "b", bluetoothJustification);
	    }
	
		if( notificationCount > 0 ) {
	        // Draw notification count & message bubble directly to the main screen.
	        deviceContext.drawText(notificationCountLocation, 54, font, "m", notificationJustification);
	        targetDeviceContext.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
	        deviceContext.drawText(notificationCountLocation-4, 52, Graphics.FONT_TINY, notificationCount, notificationJustification);
	        targetDeviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
	    }

        // Draw the battery percentage directly to the main screen.
        deviceContext.drawText(195, height/2, Graphics.FONT_TINY, (System.getSystemStats().battery + 0.5).toNumber().toString() + "%", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw the number of steps directly to the main screen.
        var steps = ActivityMonitor.getInfo().steps.toString();
        deviceContext.drawText(23, height/2, Graphics.FONT_TINY, steps, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);


        // Draw the hour hand. Convert it to minutes and compute the angle.
        hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
        hourHandAngle = hourHandAngle / (12 * 60.0);
        hourHandAngle = hourHandAngle * Math.PI * 2;
        targetDeviceContext.fillPolygon(generateHandCoordinates(screenCenterPoint, hourHandAngle, 60, 15, 5));

        // Draw the minute hand.
        minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
        targetDeviceContext.fillPolygon(generateHandCoordinates(screenCenterPoint, minuteHandAngle, 100, 15, 4));

        if( partialUpdatesAllowed ) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate( deviceContext );
        } else if ( isAwake ) {
            // Otherwise, if we are out of sleep mode, draw the second hand
            // directly in the full update method.
            deviceContext.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            secondHand = (clockTime.sec / 60.0) * Math.PI * 2;

            deviceContext.fillPolygon(generateHandCoordinates(screenCenterPoint, secondHand, 100, 25, 2));
        }
        
        // Draw the arbor in the center of the screen.
        targetDeviceContext.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        targetDeviceContext.fillCircle(width / 2, height / 2, 7);
        targetDeviceContext.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        targetDeviceContext.fillCircle(width / 2, height / 2, 4);

        fullScreenRefresh = false;
    }

    // Draw the date string into the provided buffer at the specified location
    function drawDateString( deviceContext, x, y ) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
//        deviceContext.drawText(x, y, font, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
        deviceContext.drawText(x, y, Graphics.FONT_TINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Handle the partial update event
    function onPartialUpdate( deviceContext ) {
        // If we're not doing a full screen refresh we need to re-draw the background
        // before drawing the updated second hand position. Note this will only re-draw
        // the background in the area specified by the previously computed clipping region.
        if(!fullScreenRefresh) {
            drawBackground(deviceContext);
        }

        var clockTime = System.getClockTime();
        var secondHand = (clockTime.sec / 60.0) * Math.PI * 2;
        var secondHandPoints = generateHandCoordinates(screenCenterPoint, secondHand, 60, 20, 2);

        // Update the cliping rectangle to the new location of the second hand.
        curClip = getBoundingBox( secondHandPoints );
        var bboxWidth = curClip[1][0] - curClip[0][0] + 1;
        var bboxHeight = curClip[1][1] - curClip[0][1] + 1;
        deviceContext.setClip(curClip[0][0], curClip[0][1], bboxWidth, bboxHeight);

        // Draw the second hand to the screen.
        deviceContext.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        deviceContext.fillPolygon(secondHandPoints);
    }

    // Compute a bounding box from the passed in points
    function getBoundingBox( points ) {
        var min = [9999,9999];
        var max = [0,0];

        for (var i = 0; i < points.size(); ++i) {
            if(points[i][0] < min[0]) {
                min[0] = points[i][0];
            }

            if(points[i][1] < min[1]) {
                min[1] = points[i][1];
            }

            if(points[i][0] > max[0]) {
                max[0] = points[i][0];
            }

            if(points[i][1] > max[1]) {
                max[1] = points[i][1];
            }
        }

        return [min, max];
    }

    // Draw the watch face background
    // onUpdate uses this method to transfer newly rendered Buffered Bitmaps
    // to the main display.
    // onPartialUpdate uses this to blank the second hand from the previous
    // second before outputing the new one.
    function drawBackground(deviceContext) {
        var width = deviceContext.getWidth();
        var height = deviceContext.getHeight();

        //If we have an offscreen buffer that has been written to
        //draw it to the screen.
        if( null != offscreenBuffer ) {
            deviceContext.drawBitmap(0, 0, offscreenBuffer);
        }

        // Draw the date
        if( null != dateBuffer ) {
            // If the date is saved in a Buffered Bitmap, just copy it from there.
            deviceContext.drawBitmap(0, (height / 4), dateBuffer );
        } else {
            // Otherwise, draw it from scratch.
//            drawDateString( deviceContext, width / 2, height / 4 );
            drawDateString( deviceContext, width/2, 163 );
        }
    }

    // This method is called when the device re-enters sleep mode.
    // Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
    function onEnterSleep() {
        isAwake = false;
        WatchUi.requestUpdate();
    }

    // This method is called when the device exits sleep mode.
    // Set the isAwake flag to let onUpdate know it should render the second hand.
    function onExitSleep() {
        isAwake = true;
    }
}

class AnalogDelegate extends WatchUi.WatchFaceDelegate {
    // The onPowerBudgetExceeded callback is called by the system if the
    // onPartialUpdate method exceeds the allowed power budget. If this occurs,
    // the system will stop invoking onPartialUpdate each second, so we set the
    // partialUpdatesAllowed flag here to let the rendering methods know they
    // should not be rendering a second hand.
    function onPowerBudgetExceeded(powerInfo) {
        System.println( "Average execution time: " + powerInfo.executionTimeAverage );
        System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
        partialUpdatesAllowed = false;
    }
}
