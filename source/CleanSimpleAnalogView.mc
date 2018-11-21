using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Application;

// This implements an analog watch face
// Original design by Austen Harbour
class CleanSimpleAnalogView extends WatchUi.WatchFace {
    var hoursDigitsFont;
    var secondsDialsFont;
    var isAwake = false;
    var screenShape;
    var dndIcon;
    var partialUpdatesAllowed;
    var offscreenBuffer;
    var needsClip = false;
    var curClip;
    var screenCenterPoint;
    var width;
    var height;
    var widthDiv2;
    var heightDiv2;
    var widthDiv3;
    var heightDiv3;
    var width75;
	var handsOutlineColor;
	var hourHashMarksColor;
    var secondHandType;
    var showAllHourNumbers;
    var hourNumberLocation1;
    var hourNumberLocation2;
    var hourNumberLocation3;
    var hourNumberLocation4;
    var bluetoothAndNotificatoinCountLocation;
	var dialNotificationCountLocationX;
	var notificationCountLocationXOffset;
    var notificationCountLocationY;
    var notificationTextLocationY;
    var bubble;
    var batteryPercentageLocationX;
    var stepsLocationX;
    
    var minuteHandPoints = [[-2,15], [-2,-90], [0, -100], [2,-90], [2,15]];
    var hourHandPoints = [[-3,15], [-3,-50], [0, -60], [3,-50], [3,15]];
    var secondHandPoints = [[-1,25], [-1,-100], [1,-100], [1,25]];

    // Initialize variables for this view
    function initialize() {
        WatchFace.initialize();
        screenShape = System.getDeviceSettings().screenShape;
        partialUpdatesAllowed = ( Toybox.WatchUi.WatchFace has :onPartialUpdate );
        if( partialUpdatesAllowed ) {
        } else {
        	partialUpdatesAllowed = false;
        }
        
        var app = Application.getApp();
        var handsOutline = app.getProperty("handsOutline");
        var hourHashMarks = app.getProperty("hourHashMarks");
        secondHandType = app.getProperty("secondHandType");
        showAllHourNumbers = app.getProperty("showAllHourNumbers");
/* for testing...        
       handsOutline = 5;
        hourHashMarks = 9;
        secondHandType = 1;
*/
		handsOutlineColor = getColor(handsOutline);
		hourHashMarksColor = getColor(hourHashMarks);
    }

    // Configure the layout of the watchface for this device
    function onLayout(deviceContext) {
	    // initialize a bunch of values based off of screen size
        width = deviceContext.getWidth();
        height = deviceContext.getHeight();
        widthDiv2 = width/2;
        heightDiv2 = height/2;
        widthDiv3 = width/3;
        heightDiv3 = height/3;
        
        var minuteHandTailLength = height/14.53;
        var minuteHandHeadLength = height/-2.42;
        minuteHandPoints[0] = [-2, minuteHandTailLength];
        minuteHandPoints[1] = [-2, minuteHandHeadLength];
        minuteHandPoints[2] = [ 0, height/-2.18];			// tip
        minuteHandPoints[3] = [ 2, minuteHandHeadLength];
        minuteHandPoints[4] = [ 2, minuteHandTailLength];

        var hourHandTailLength = height/14.53;
        var hourHandHeadLength = height/-4.36;
        hourHandPoints[0] = [-3, hourHandTailLength];
        hourHandPoints[1] = [-3, hourHandHeadLength];
        hourHandPoints[2] = [ 0, height/-3.63];				// tip
        hourHandPoints[3] = [ 3, hourHandHeadLength];
        hourHandPoints[4] = [ 3, hourHandTailLength];

        var secondHandTailLength = height/8.72;
        var secondHandHeadLength = height/-2.18;
        secondHandPoints[0] = [-1, secondHandTailLength];
        secondHandPoints[1] = [-1, secondHandHeadLength];
        secondHandPoints[2] = [ 1, secondHandHeadLength];
        secondHandPoints[3] = [ 1, secondHandTailLength];

		hourNumberLocation1 = height/6.5;
		hourNumberLocation2 = height/3.5;
		hourNumberLocation3 = height-hourNumberLocation2;
		hourNumberLocation4 = height-hourNumberLocation1;

		bluetoothAndNotificatoinCountLocation = height/7.26;
		dialNotificationCountLocationX = width*2/3+4;
		notificationCountLocationY = height/4;
		batteryPercentageLocationX = width/1.12;
		stepsLocationX = width/9.5;
        if( width > 218 ) {
        	bubble = "n";
        	notificationCountLocationXOffset = 3;
        	notificationCountLocationY -= 5;
        	notificationTextLocationY = notificationCountLocationY;
        } else {
        	bubble = "m";
        	notificationCountLocationXOffset = 0;
        	notificationTextLocationY = notificationCountLocationY-2;
        }

        width75 = width*.75;
		
        // Load the custom fonts we use
        hoursDigitsFont = WatchUi.loadResource(Rez.Fonts.id_font_hours_digits);
        secondsDialsFont = WatchUi.loadResource(Rez.Fonts.id_font_seconds_dials);

        // If this device supports the Do Not Disturb feature, load the associated Icon into memory.
        if( System.getDeviceSettings() has :doNotDisturb ) {
            dndIcon = WatchUi.loadResource(Rez.Drawables.DoNotDisturbIcon);
        } else {
            dndIcon = null;
        }

        // If this device supports BufferedBitmap, allocate the buffers we use for drawing
        if( Toybox.Graphics has :BufferedBitmap ) {
            // Allocate a full screen size buffer.  This buffer is used to draw the watch face between full minute updates when the second hand is the only thing being updated.
            offscreenBuffer = new Graphics.BufferedBitmap({
                :width=>deviceContext.getWidth(),
                :height=>deviceContext.getHeight()
            });

        } else {
            offscreenBuffer = null;
        }

        curClip = null;

        screenCenterPoint = [widthDiv2, heightDiv2];
    }

	function getColor(colorCode) {
		var color = Graphics.COLOR_TRANSPARENT;
		if( colorCode == 0 ) {
			color = Graphics.COLOR_TRANSPARENT;
		} else if( colorCode == 1 ) {
			color = Graphics.COLOR_WHITE;
		} else if( colorCode == 2 ) {
			color = Graphics.COLOR_LT_GRAY;
		} else if( colorCode == 3 ) {
			color = Graphics.COLOR_DK_GRAY;
		} else if( colorCode == 4 ) {
			color = Graphics.COLOR_BLACK;
		} else if( colorCode == 5 ) {
			color = Graphics.COLOR_RED;
		} else if( colorCode == 6 ) {
			color = Graphics.COLOR_DK_RED;
		} else if( colorCode == 7 ) {
			color = Graphics.COLOR_ORANGE;
		} else if( colorCode == 8 ) {
			color = Graphics.COLOR_YELLOW;
		} else if( colorCode == 9 ) {
			color = Graphics.COLOR_GREEN;
		} else if( colorCode == 10 ) {
			color = Graphics.COLOR_DK_GREEN;
		} else if( colorCode == 11 ) {
			color = Graphics.COLOR_BLUE;
		} else if( colorCode == 12 ) {
			color = Graphics.COLOR_DK_BLUE;
		} else if( colorCode == 13 ) {
			color = Graphics.COLOR_PURPLE;
		} else if( colorCode == 14 ) {
			color = Graphics.COLOR_PINK;
		}		
		return color;
	}

    // Handle the update event
    function onUpdate(deviceContext) {
        var targetDeviceContext = null;
        
        if( null != offscreenBuffer ) {
            deviceContext.clearClip();
            curClip = null;
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDeviceContext = offscreenBuffer.getDc();
        } else {
            targetDeviceContext = deviceContext;
        }

        var clockTime = System.getClockTime();

        // Fill the entire background with Black.
        targetDeviceContext.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        targetDeviceContext.fillRectangle(0, 0, width, height);

        // Draw the tick marks around the edges of the screen
        drawHashMarks(targetDeviceContext);

        // Draw the do-not-disturb icon if we support it and the setting is enabled
        if( null != dndIcon && System.getDeviceSettings().doNotDisturb ) {
            targetDeviceContext.drawBitmap( width75, heightDiv2 - 15, dndIcon);
        }

        // Use white
        targetDeviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Draw the 3, 6, 9, and 12 hour labels.
        targetDeviceContext.drawText((widthDiv2), 0, hoursDigitsFont, "12", Graphics.TEXT_JUSTIFY_CENTER);
        targetDeviceContext.drawText(width - 2, heightDiv2+2, hoursDigitsFont, "3", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        targetDeviceContext.drawText(widthDiv2, height-25, hoursDigitsFont, "6", Graphics.TEXT_JUSTIFY_CENTER);
        targetDeviceContext.drawText(2, heightDiv2+2, hoursDigitsFont, "9", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

		if( showAllHourNumbers ) {
			// draw other smaller hour labels
			targetDeviceContext.drawText(hourNumberLocation3, hourNumberLocation1,  Graphics.FONT_TINY, "1", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation4, hourNumberLocation2,  Graphics.FONT_TINY, "2", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation4, hourNumberLocation3, Graphics.FONT_TINY,  "4", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation3, hourNumberLocation4,  Graphics.FONT_TINY, "5", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation2, hourNumberLocation4, Graphics.FONT_TINY,  "7", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation1, hourNumberLocation3,  Graphics.FONT_TINY, "8", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation1, hourNumberLocation2, Graphics.FONT_TINY, "10", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			targetDeviceContext.drawText(hourNumberLocation2, hourNumberLocation1, Graphics.FONT_TINY, "11", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		}

		drawDateString( targetDeviceContext, widthDiv2, hourNumberLocation3 );

		var isBluetoothConnected= System.getDeviceSettings().phoneConnected;
		var notificationCount = System.getDeviceSettings().notificationCount;
		
		var bluetoothConnectedLocationX = widthDiv2;
		var bluetoothConnectedLocationY;
		var notificationCountLocationX;
		var bluetoothJustification;
		var notificationJustification;
		if( secondHandType == 0 || ( ! partialUpdatesAllowed && ! isAwake )  ) {
			// sweep hand or dial hand but dial currently not being shown (no partial updates and not awake)
			bluetoothConnectedLocationY = notificationCountLocationY+1;
			notificationCountLocationX = widthDiv2;
			bluetoothJustification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
			notificationJustification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
			if( isBluetoothConnected && notificationCount > 0 ) {
				bluetoothConnectedLocationX = bluetoothConnectedLocationX - bluetoothAndNotificatoinCountLocation;
				notificationCountLocationX = notificationCountLocationX + bluetoothAndNotificatoinCountLocation;
				bluetoothJustification = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
				notificationJustification = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
			}
		} else {
			// dial hand
			if( width > 218 ) {			
				bluetoothConnectedLocationY = notificationCountLocationY+3;
			} else {
				bluetoothConnectedLocationY = notificationCountLocationY;
			}			
			notificationCountLocationX = dialNotificationCountLocationX;
			bluetoothJustification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
			notificationJustification = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
		}
		
        targetDeviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		if( isBluetoothConnected ) {
	        // Draw bluetooth connected indicator
	        targetDeviceContext.drawText(bluetoothConnectedLocationX, bluetoothConnectedLocationY, hoursDigitsFont, "b", bluetoothJustification);
	    }
	
		if( notificationCount > 0 ) {
	        // Draw notification count & message bubble
	        notificationCountLocationX += notificationCountLocationXOffset;
	        targetDeviceContext.drawText(notificationCountLocationX, notificationCountLocationY, hoursDigitsFont, bubble, notificationJustification);
	        targetDeviceContext.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
	        targetDeviceContext.drawText(notificationCountLocationX-4, notificationTextLocationY, Graphics.FONT_TINY, notificationCount, notificationJustification);
	        targetDeviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
	    }

        // Draw the battery percentage
        targetDeviceContext.drawText( batteryPercentageLocationX, heightDiv2, Graphics.FONT_TINY,
        								(System.getSystemStats().battery + 0.5).toNumber().toString() + "%", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw the number of steps
        var steps = ActivityMonitor.getInfo().steps.toString();
        targetDeviceContext.drawText(stepsLocationX, heightDiv2, Graphics.FONT_TINY, steps, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

		drawHourAndMinuteHands(targetDeviceContext, clockTime);
		
        if( partialUpdatesAllowed ) {
            // If this device supports partial updates and they are currently allowed run the onPartialUpdate method to draw the second hand.
            needsClip = false;	// no clipping; fullscreen update
            onPartialUpdate( deviceContext );
            needsClip = true;	// clip for future partial screen updates
        } else if ( isAwake ) {
	        // Output the offscreen buffer (if used) to the main display
	        drawOffscreenBuffer(deviceContext);
	        
            // In high power mode so draw the second hand directly to the screen in this full update method.
            if( secondHandType == 0 ) {
            	// sweep second hand type
	            deviceContext.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
	            var secondHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;
				var secondHandCoordinates = rotateHand(secondHandPoints, secondHandAngle, screenCenterPoint);
	            deviceContext.fillPolygon(secondHandCoordinates);
            } else {
            	// dial second hand type
	            deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            	var seconds = getSecondsChar(clockTime.sec);
        		deviceContext.drawText(widthDiv3, heightDiv3, secondsDialsFont, seconds, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        		// draw hour and minutes hands after dial second hand
				drawHourAndMinuteHands(deviceContext, clockTime);
            }
        }
    }

	function drawHourAndMinuteHands(deviceContext, clockTime) {
        // Draw the hour hand. Convert it to minutes and compute the angle.
        var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
        hourHandAngle = hourHandAngle / (12 * 60.0);
        hourHandAngle = hourHandAngle * Math.PI * 2;
		var hourHandCoordinates = rotateHand(hourHandPoints, hourHandAngle, screenCenterPoint);
        deviceContext.fillPolygon(hourHandCoordinates);

		// Draw outline of hour hand
		drawHandOutline(deviceContext, hourHandCoordinates);

        // Draw the minute hand
		deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
		var minuteHandCoordinates = rotateHand(minuteHandPoints, minuteHandAngle, screenCenterPoint);
        deviceContext.fillPolygon(minuteHandCoordinates);

		// Draw outline of minute hand
		drawHandOutline(deviceContext, minuteHandCoordinates);

        // Draw the arbor in the center of the screen.
        deviceContext.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        deviceContext.fillCircle(widthDiv2, heightDiv2, 7);
        deviceContext.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        deviceContext.fillCircle(widthDiv2, heightDiv2, 4);        
	}

	function drawHandOutline(deviceContext, handCoordinates) {
		if( handsOutlineColor != Graphics.COLOR_TRANSPARENT ) {
			deviceContext.setColor(handsOutlineColor, Graphics.COLOR_TRANSPARENT);
			
			for( var i=0; i<handCoordinates.size()-1; ++i ) {
				var secondX = i+1;
				if( i == handCoordinates.size()-1 ) {
					secondX = 0;
				} 
				deviceContext.drawLine(handCoordinates[i][0], handCoordinates[i][1], handCoordinates[secondX][0], handCoordinates[secondX][1]);
			}
		}	
	}

    // Draw the watch face stored in the offscreen buffer if available
    // onUpdate() uses this method to transfer newly rendered Buffered Bitmaps to the main display.
    // onPartialUpdate() uses this to blank the second hand from the previous second before outputing the new one.
    function drawOffscreenBuffer(deviceContext) {
        // If we have an offscreen buffer, draw it to the screen.
        if( null != offscreenBuffer ) {
            deviceContext.drawBitmap(0, 0, offscreenBuffer);
        }
    }

    // Draw the date string into the provided buffer at the specified location
    function drawDateString( deviceContext, x, y ) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        deviceContext.drawText(x, y, Graphics.FONT_TINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Handle the partial update event
    function onPartialUpdate( deviceContext ) {
        var clockTime = System.getClockTime();
        var secondHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;
        // Re-draw the watch face before drawing the updated second hand position.
        // Note this will only re-draw the background in the area specified by the previously computed clipping region.
		drawOffscreenBuffer(deviceContext);

        if( secondHandType == 0 ) {
        	// sweep second hand type
        	
			var secondHandCoordinates = rotateHand(secondHandPoints, secondHandAngle, screenCenterPoint);
	
	        // Update the clipping rectangle to the new location of the second hand.
	        curClip = getBoundingBox( secondHandCoordinates );
	        var bboxWidth = curClip[1][0] - curClip[0][0] + 1;
	        var bboxHeight = curClip[1][1] - curClip[0][1] + 1;
	        deviceContext.setClip(curClip[0][0], curClip[0][1], bboxWidth, bboxHeight);
	
	        // Draw the second hand to the screen.
	        deviceContext.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
	        deviceContext.fillPolygon(secondHandCoordinates);
		} else {
           	// dial second hand type
            deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        	var seconds = getSecondsChar(clockTime.sec);
        	if( needsClip ) {
	        	deviceContext.setClip(widthDiv3-28, heightDiv3-28, 56, 56);
	        }
    		deviceContext.drawText(widthDiv3, heightDiv3, secondsDialsFont, seconds, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    		// draw hour and minutes hands after dial second hand
			drawHourAndMinuteHands(deviceContext, clockTime);
		}
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

	function rotateHand(handPoints, angle, centerPoint) {
        var result = new [handPoints.size()];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < handPoints.size(); i += 1) {
            var x = (handPoints[i][0] * cos) - (handPoints[i][1] * sin) + 0.5;
            var y = (handPoints[i][0] * sin) + (handPoints[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }
    
    // Draws the clock tick marks around the outside edges of the screen.
    function drawHashMarks(deviceContext) {
    	if( hourHashMarksColor != Graphics.COLOR_TRANSPARENT ) {
	        deviceContext.setColor(hourHashMarksColor, Graphics.COLOR_TRANSPARENT);
	
	        // Draw hashmarks differently depending on screen geometry.
	        if (System.SCREEN_SHAPE_ROUND == screenShape) {
	            var sX, sY;
	            var eX, eY;
	            var outerRad = widthDiv2;
	            var innerRad = outerRad - 10;	// length of hashmark
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
	                var dx = (widthDiv2 - coords[i]) / heightDiv2;
	                var upperX = coords[i] + (dx * 10);
	                // Draw the upper hash marks.
	                deviceContext.fillPolygon([[coords[i] - 1, 2], [upperX - 1, 12], [upperX + 1, 12], [coords[i] + 1, 2]]);
	                // Draw the lower hash marks.
	                deviceContext.fillPolygon([[coords[i] - 1, height-2], [upperX - 1, height - 12], [upperX + 1, height - 12], [coords[i] + 1, height - 2]]);
	            }
	        }
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
    
    function getSecondsChar(seconds) {
    	if( seconds == 0 ) {
    		return "0";
    	} else if( seconds == 1 ) {
    		return "1";
    	} else if( seconds == 2 ) {
    		return "2";
    	} else if( seconds == 3 ) {
    		return "3";
    	} else if( seconds == 4 ) {
    		return "4";
    	} else if( seconds == 5 ) {
    		return "5";
    	} else if( seconds == 6 ) {
    		return "6";
    	} else if( seconds == 7 ) {
    		return "7";
    	} else if( seconds == 8 ) {
    		return "8";
    	} else if( seconds == 9 ) {
    		return "9";
    	} else if( seconds == 10 ) {
    		return "!";
    	} else if( seconds == 11 ) {
    		return "\"";
    	} else if( seconds == 12 ) {
    		return "#";
    	} else if( seconds == 13 ) {
    		return "$";
    	} else if( seconds == 14 ) {
    		return "%";
    	} else if( seconds == 15 ) {
    		return "&";
    	} else if( seconds == 16 ) {
    		return "'";
    	} else if( seconds == 17 ) {
    		return "(";
    	} else if( seconds == 18 ) {
    		return ")";
    	} else if( seconds == 19 ) {
    		return "*";
    	} else if( seconds == 20 ) {
    		return "+";
    	} else if( seconds == 21 ) {
    		return ",";
    	} else if( seconds == 22 ) {
    		return "-";
    	} else if( seconds == 23 ) {
    		return ".";
    	} else if( seconds == 24 ) {
    		return "/";
    	} else if( seconds == 25 ) {
    		return ":";
    	} else if( seconds == 26 ) {
    		return ";";
    	} else if( seconds == 27 ) {
    		return "<";
    	} else if( seconds == 28 ) {
    		return "=";
    	} else if( seconds == 29 ) {
    		return "?";
    	} else if( seconds == 30 ) {
    		return "@";
    	} else if( seconds == 31 ) {
    		return "A";
    	} else if( seconds == 32 ) {
    		return "B";
    	} else if( seconds == 33 ) {
    		return "C";
    	} else if( seconds == 34 ) {
    		return "D";
    	} else if( seconds == 35 ) {
    		return "E";
    	} else if( seconds == 36 ) {
    		return "F";
    	} else if( seconds == 37 ) {
    		return "G";
    	} else if( seconds == 38 ) {
    		return "H";
    	} else if( seconds == 39 ) {
    		return "I";
    	} else if( seconds == 40 ) {
    		return "J";
    	} else if( seconds == 41 ) {
    		return "K";
    	} else if( seconds == 42 ) {
    		return "L";
    	} else if( seconds == 43 ) {
    		return "M";
    	} else if( seconds == 44 ) {
    		return "N";
    	} else if( seconds == 45 ) {
    		return "O";
    	} else if( seconds == 46 ) {
    		return "P";
    	} else if( seconds == 47 ) {
    		return "Q";
    	} else if( seconds == 48 ) {
    		return "R";
    	} else if( seconds == 49 ) {
    		return "S";
    	} else if( seconds == 50 ) {
    		return "T";
    	} else if( seconds == 51 ) {
    		return "U";
    	} else if( seconds == 52 ) {
    		return "V";
    	} else if( seconds == 53 ) {
    		return "W";
    	} else if( seconds == 54 ) {
    		return "X";
    	} else if( seconds == 55 ) {
    		return "Y";
    	} else if( seconds == 56 ) {
    		return "Z";
    	} else if( seconds == 57 ) {
    		return "[";
    	} else if( seconds == 58 ) {
    		return "\\";
    	} else {
    		return "]";
    	}
    }
}


class AnalogDelegate extends WatchUi.WatchFaceDelegate {
    // The onPowerBudgetExceeded callback is called by the system if the onPartialUpdate() method exceeds the allowed power budget.
    // If this occurs, the system will stop invoking onPartialUpdate each second, so we set the partialUpdatesAllowed flag here to let the rendering methods know they
    // should not be rendering a second hand.
    function onPowerBudgetExceeded(powerInfo) {
        System.println( "Average execution time: " + powerInfo.executionTimeAverage );
        System.println( "Allowed execution time: " + powerInfo.executionTimeLimit );
        partialUpdatesAllowed = false;
    }
}
