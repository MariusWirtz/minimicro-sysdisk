// This demo makes a GUI interface based on the famous LCARS UI,
// complete with a working file manager and other tools.
//
// It's mostly a matter of laying out panels with buttons and other
// widgets.

import "importUtil"
ensureImport "listUtil"
ensureImport "mathUtil"
ensureImport "events"
ensureImport "bmfFonts"
ensureImport "dateTime"
ensureImport "gui"

clear
spriteDisp = display(4)
display(7).mode = displayMode.pixel
scratch = display(7)
gfx.clear color.black

smallFont = bmfFonts.Font.load("/sys/fonts/minimicro-pro-12.bmf")
mediumFont = bmfFonts.Font.load("/usr/fonts/minimicro-pro-16.bmf")	// ToDo: get this on /sys!
largeFont = bmfFonts.Font.load("/sys/fonts/minimicro-pro-20.bmf")

resourcePic = file.loadImage("/usr/data/desktop/desktopGfx.png")	// ToDo: get from /sys
swoopImages = []
w = 163; h = 73
for i in range(0,3)
	swoopImages.push resourcePic.getImage(512-w*2+(i%2)*w, 512-h-h*floor(i/2), w, h)
end for
oval48 = gui.Image9Slice.make(resourcePic.getImage(464, 0, 48, 48), 24,24,24,24)
oval32 = gui.Image9Slice.make(resourcePic.getImage(424, 0, 32, 32), 16,16,16,16)
oval24 = gui.Image9Slice.make(resourcePic.getImage(392, 0, 24, 24), 12,12,12,12)


//----------------------------------------------------------------------
Style = {}
Style.spacing = 2
Style.buttonHeight = 32
Style.buttonWidth = 120
Style.topBarHeight = function; return self.buttonHeight; end function
Style.bottomBarHeight = function; return self.topBarHeight; end function
Style.leftBarWidth = 120
Style.rightBarWidth = function; return self.leftBarWidth; end function
Style.swoopExtra = [64,48]

// colors reference: https://www.thelcars.com/colors.php
Style.color = "#FFEBDE"			// fallback color
Style.blockColor = function; return self.color; end function
Style.infoBlockColor = function; return self.blockColor; end function
Style.buttonColor = "#FFAA00"
Style.swoopColor = function; return self.infoBlockColor; end function

//----------------------------------------------------------------------
Panel = {}
Panel.parent = null		// reference to parent
Panel.children = null	// list of children
Panel.left = 0
Panel.bottom = 0
Panel.width = 0
Panel.height = 0
Panel.style = Style
Panel.area = function; return self.width * self.height; end function
Panel.right = function; return self.left + self.width; end function
Panel.top = function; return self.bottom + self.height; end function
Panel.midX = function; return self.left + self.width/2; end function
Panel.midY = function; return self.bottom + self.height/2; end function

Panel.make = function(parent, left, bottom, width, height)
	p = new Panel
	if parent != null then
		parent.addChild p
		if left == null then left = parent.left
		if bottom == null then bottom = parent.bottom
		if width == null then width = parent.right - left
		if height == null then height = parent.top - bottom
		p.style = new parent.style
	end if
	p.left = left
	p.bottom = bottom
	p.width = width
	p.height = height
	p.children = []
	return p
end function

Panel.unparent = function
	if self.parent then self.parent.children.removeVal self
	self.parent = null
end function

Panel.addChild = function(child)
	child.unparent
	child.parent = self
	self.children.push child
end function

Panel.offset = function(dx, dy)
	return Panel.make(self.left + dx, self.bottom + dy, self.width, self.height)
end function

Panel.grow = function(dwidth, dheight)
	return Panel.make(self.left, self.bottom, self.width + dwidth, self.height + dheight)
end function

Panel.setTop = function(newTop)
	self.bottom = newTop - self.height
end function

Panel.setRight = function(newRight)
	self.left = newRight - self.width
end function

Panel.contains = function(pt)
	return pt.x >= self.left and pt.x < self.left + self.width and
	  pt.y >= self.bottom and pt.y < self.bottom + self.height
end function

Panel.debugDraw = function(g)
	if g == null then g = gfx
	g.drawRect self.left, self.bottom, self.width, self.height
	s = mapName(self.__isa)
	g.print s, self.left+3, self.bottom+3, g.color, "small"
	for child in self.children
		child.debugDraw g
	end for
end function

Panel.present = function
	for child in self.children
		child.present
	end for
end function

Panel.dismiss = function
	gfx.fillRect self.left, self.bottom, self.width, self.height, color.black
	for child in self.children
		child.dismiss
	end for
end function

Panel.destroy = function
	for child in self.children
		child.destroy
		child.parent = null
	end for
	children = null
end function

//----------------------------------------------------------------------
// Block: a panel that just draws a solid color
Block = new Panel
Block.make = function(parent, left, bottom, width, height)
	p = super.make(parent, left, bottom, width, height)
	p.__isa = self
	return p
end function

Block.present = function
	gfx.fillRect self.left, self.bottom, self.width, self.height, self.style.blockColor
	super.present
end function


//----------------------------------------------------------------------
// Gap: a special panel that represents a flexible gap in a layout of subpanels.
Gap = new Block
Gap.make = function(parent)
	p = new Gap
	if parent != null then parent.addChild p
	return p
end function
	
Panel.layout = function
	gapCount = 0
	lastGap = null
	if self.width > self.height then
		// lay out children horizontally
		remainder = self.width - self.style.spacing * (self.children.len - 1)
		for child in self.children
			child.bottom = self.bottom; child.height = self.height
			child.left = 0
			if child.width == null then child.width = self.style.buttonWidth
			if child isa Gap then
				gapCount += 1
				lastGap = child
			else
				remainder -= child.width
			end if
		end for
		perGapWidth = floor(remainder / gapCount)
		gapsLeft = gapCount
		x = self.left
		for child in self.children
			if child isa Gap then
				if gapsLeft == 1 then child.width = remainder else child.width = perGapWidth
				remainder -= perGapWidth
				gapsLeft -= 1
			end if
			child.left = x
			x += child.width + self.style.spacing
		end for		
	else
		// lay out children vertically
		remainder = self.height - self.style.spacing * (self.children.len - 1)
		for child in self.children
			child.left = self.left; child.width = self.width
			child.bottom = 0
			if child.height == null then child.height = self.style.buttonHeight
			if child isa Gap then
				gapCount += 1
				lastGap = child
			else
				remainder -= child.height
			end if
		end for
		perGapHeight = floor(remainder / gapCount)
		gapsLeft = gapCount
		y = self.top
		for child in self.children
			if child isa Gap then
				if gapsLeft == 1 then child.height = remainder else child.height = perGapHeight
				remainder -= perGapHeight
				gapsLeft -= 1
			end if
			child.setTop y
			y -= child.height + self.style.spacing
		end for
	end if
end function

//----------------------------------------------------------------------
// Button: a panel that's clickable.
Button = new Panel
Button.caption = ""
Button.captionFont = mediumFont
Button.sprite = null
Button.action = null
Button.key = ""			// shortcut key, or list of keys
Button.keyButton = {}
Button.make = function(caption, parent, left, bottom, width, height)
	p = super.make(parent, left, bottom, width, height)
	p.__isa = self
	p.caption = caption
	if caption.len == 1 then p.key = caption
	return p
end function

Button.checkKey = function(k)
	if not Button.keyButton.hasIndex(k) then return false
	btn = Button.keyButton[k]
	btn.sprite.tint = btn.pressedColor
	wait 0.2
	btn.sprite.tint = btn.color
	btn.action
end function

Button.drawToScratch = function
	scratch.fillRect 0, 0, self.width, self.height, color.white
	globals.gfx = scratch
	self.captionFont.printRight self.caption, self.width-4, 4, 1, color.black
	globals.gfx = display(5)
end function

Button.makeSprite = function
	self.drawToScratch
	if self.sprite == null then self.sprite = new events.EventSprite
	self.sprite.image = scratch.getImage(0, 0, self.width, self.height)
	self.sprite.tint = self.color
	self.sprite.x = self.midX
	self.sprite.y = self.midY
	self.sprite.button = self
	self.sprite.onClick = function; self.button.onClick; end function
	self.sprite.onDrag = function; self.button.onDrag; end function
	self.sprite.onDragEnd = function; self.button.onDragEnd; end function
end function

Button.present = function
	if self.sprite == null then self.makeSprite
	self.sprite.start
	if self.key isa list then
		for k in self.key
			Button.keyButton[k] = self
		end for
	else
		Button.keyButton[self.key] = self
	end if
	super.present
end function

Button.dismiss = function
	self.sprite.stop
	if self.key isa list then
		for k in self.key
			Button.keyButton.remove k
		end for
	else
		Button.keyButton.remove self.key
	end if
	if self.key then Button.keyButton.remove self.key
	super.dismiss
end function

Button.color = function; return self.style.buttonColor; end function
Button.pressedColor = function
	return color.lerp(self.color, color.black, 0.1)
end function

Button.onClick = function
	self.sprite.tint = self.pressedColor
end function

Button.onDrag = function
	if self.contains(mouse) then
		self.sprite.tint = self.pressedColor
	else
		self.sprite.tint = self.color
	end if
end function

Button.onDragEnd = function
	self.sprite.tint = self.color
	if self.contains(mouse) then self.action
end function

//----------------------------------------------------------------------
// RoundButton: a button with round endcaps.
// Height should be 24, 32, or 48 for best roundness.
RoundButton = new Button
RoundButton.make = function(caption, parent, left, bottom, width, height)
	p = super.make(caption, parent, left, bottom, width, height)
	p.__isa = self
	return p
end function

RoundButton.drawToScratch = function
	globals.gfx = scratch
	gfx.fillRect 0, 0, self.width, self.height, color.black
	pic = oval24
	if self.height >= 32 then pic = oval32
	if self.height >= 48 then pic = oval48
	pic.draw gfx, 0, 0, self.width, self.height
	self.captionFont.printRight self.caption, self.width-self.height/2, 4, 1, color.black
	globals.gfx = display(5)
end function

//----------------------------------------------------------------------
// InfoBlock: a block that shows some text
InfoBlock = new Panel
InfoBlock.font = mediumFont
InfoBlock.inverted = false	// if true, draw colored text on black background
InfoBlock.make = function(text, parent, left, bottom, width, height)
	p = super.make(parent, left, bottom, width, height)
	p.__isa = self
	p.text = text
	return p
end function

InfoBlock.present = function
	gfx.color = self.style.infoBlockColor * (not self.inverted) + color.black * self.inverted
	gfx.fillRect self.left, self.bottom, self.width, self.height
	textColor = self.style.infoBlockColor * self.inverted + color.black * (not self.inverted)
	self.font.printCentered self.text, self.midX, self.midY - self.font.lineHeight/2, 1, textColor
end function

//----------------------------------------------------------------------
// Swoop: swoopy corner piece for a Frame (below).
Swoop = new Panel
Swoop.which = 0		// 0=top left, 1=top right, 2=bot left, 3=bot right
Swoop.make = function(which, parent, left, bottom, width, height)
	if width == null then width = swoopImages[0].width + 12
	if height == null then height = swoopImages[0].height + 12
	p = super.make(parent, left, bottom, width, height)
	p.__isa = self
	p.which = which
	return p
end function

Swoop.present = function
	gfx.color = self.style.swoopColor
	w = swoopImages[0].width	// (it's OK, they're all the same size)
	h = swoopImages[0].height
	vertWidth = 120
	horzHeight = 32
	if self.which == 0 then			// top left
		gfx.drawImage swoopImages[0], self.left, self.top - h, -1, -1,
			0, 0, -1, -1, gfx.color
		gfx.fillRect self.left, self.bottom, vertWidth, self.height - h
		gfx.fillRect self.left + w, self.top - horzHeight, self.width - w, horzHeight
	else if self.which == 1 then	// top right
		// ToDo
	else if self.which == 2 then	// bottom left
		gfx.drawImage swoopImages[2], self.left, self.bottom, -1, -1,
			0, 0, -1, -1, gfx.color
		gfx.fillRect self.left, self.bottom + h, vertWidth, self.height - h
		gfx.fillRect self.left + w, self.bottom, self.width - w, horzHeight
	else if self.which == 3 then	// bottom right
		// ToDo
	end if		
end function

//----------------------------------------------------------------------
// Frame: Contains content with swoopy corner(s) and side/top/bottom bars.
// Currently, this always uses a medium-thickness top/bottom (if any),
// a wide left side, and no right.  We can generalize it more later.
Frame = new Panel
Frame.topPanel = null
Frame.leftPanel = null
Frame.bottomPanel = null
Frame.rightPanel = null
Frame.make = function(parent, left, bottom, width, height)
	p = super.make(parent, left, bottom, width, height)
	p.__isa = self
	return p
end function
Frame.configure = function(hasTop, hasBottom, hasLeft=true, hasRight=false)
	if hasTop then
		left = self.left
		if hasLeft then left += self.style.leftBarWidth + self.style.swoopExtra[0]
		right = self.right
		if hasRight then right -= self.style.rightBarWidth + self.style.swoopExtra[0]
		bottom = self.top - self.style.topBarHeight
		self.topPanel = Panel.make(self, left, bottom, right-left, self.style.topBarHeight)
	end if
	if hasBottom then
		left = self.left
		if hasLeft then left += self.style.leftBarWidth + self.style.swoopExtra[0]
		right = self.right
		if hasRight then right -= self.style.rightBarWidth + self.style.swoopExtra[0]
		self.bottomPanel = Panel.make(self, left, self.bottom, right-left, self.style.topBarHeight)
	end if
	if hasLeft then
		top = self.top
		if hasTop then top -= self.style.topBarHeight + self.style.swoopExtra[1]
		bottom = self.bottom
		if hasBottom then bottom += self.style.bottomBarHeight + self.style.swoopExtra[1]
		self.leftPanel = Panel.make(self, self.left, bottom, self.style.leftBarWidth, top-bottom)
	end if
	if hasRight then
		top = self.top
		if hasTop then top -= self.style.topBarHeight + self.style.swoopExtra[1]
		bottom = self.bottom
		if hasBottom then bottom += self.style.bottomBarHeight + self.style.swoopExtra[1]
		left = self.right - self.style.rightBarWidth
		self.rightPanel = Panel.make(self, left, bottom, self.style.rightBarWidth, top-bottom)
	end if
	gap = self.style.spacing
	if hasTop and hasLeft then
		Swoop.make 0, self, self.left, self.leftPanel.top + gap,
			self.topPanel.left - gap - self.left, self.top - self.leftPanel.top - gap
	end if
	if hasBottom and hasLeft then
		Swoop.make 2, self, self.left, self.bottom,
			self.bottomPanel.left - gap - self.left, self.leftPanel.bottom - gap - self.bottom
	end if
end function


// End of general classes.  Time for...

//======================================================================
// LCARS Application

// Root: the base of our entire display
root = Panel.make(null, 0, 0, 960, 640)

//----------------------------------------------------------------------
// File Manager panel
fileManager = Panel.make(root, 168, 0, 960-168, 640)
fileManager.header = Frame.make(fileManager, null, fileManager.top - 108)
fileManager.header.configure false, true, true, false
Block.make fileManager.header.leftPanel
Block.make fileManager.header.bottomPanel
title = InfoBlock.make("FILE MANAGER", fileManager.header,
	fileManager.header.right - 200, fileManager.top - 30, 200, 30)
title.font = largeFont
title.inverted = true

fileManager.fileBox = Frame.make(fileManager, null, 0, null, fileManager.height - 118)
fileManager.fileBox.configure true, true, true, false
fileManager.fileBox.setup = function
	Button.make "UP", self.topPanel, null, null, self.style.buttonWidth
	InfoBlock.make "/usr", self.topPanel, null, null, self.topPanel.width - self.style.buttonWidth
	self.topPanel.layout
	
	Button.make "Name", self.leftPanel, null, null, null, self.style.buttonHeight
	Button.make "Size", self.leftPanel, null, null, null, self.style.buttonHeight
	Button.make "Date", self.leftPanel, null, null, null, self.style.buttonHeight
	Button.make "Selected", self.leftPanel, null, null, null, self.style.buttonHeight
	Gap.make self.leftPanel
	Button.make "Select All", self.leftPanel, null, null, null, self.style.buttonHeight
	Button.make "Select None", self.leftPanel, null, null, null, self.style.buttonHeight
	Gap.make self.leftPanel
	Button.make "Move/Copy", self.leftPanel, null, null, null, self.style.buttonHeight
	self.leftPanel.layout
	
	Button.make "Rename", self.bottomPanel, null, null, self.style.buttonWidth
	delBtn = Button.make("Delete", self.bottomPanel, null, null, self.style.buttonWidth)
	delBtn.color = "#FF3500"
	Gap.make self.bottomPanel
	Button.make "Preview", self.bottomPanel, null, null, self.style.buttonWidth
	launchBtn = Button.make("Launch", self.bottomPanel, null, null, self.style.buttonWidth)
	launchBtn.color = "#00BB00"
	self.bottomPanel.layout
end function
fileManager.fileBox.setup

//----------------------------------------------------------------------
// Clock panel
clock = Panel.make(root, 168, 0, 960-168, 640)
clock.header = Frame.make(clock, null, clock.top - 200)
clock.header.configure false, true, true, false
Block.make clock.header.leftPanel
Block.make clock.header.bottomPanel
title = InfoBlock.make("CLOCK", clock.header,
	clock.header.right - 200, clock.top - 30, 200, 30)
title.font = largeFont
title.inverted = true

//----------------------------------------------------------------------
// Calculator panel
calc = Panel.make(root, 168, 0, 960-168, 640)
calc.style.displayColor = "#88CCFF"
calc.header = Frame.make(calc, null, calc.top - 108)
calc.header.configure false, true, true, false
calc.displayStr = "0"
Block.make calc.header.leftPanel
Block.make calc.header.bottomPanel
title = InfoBlock.make("CALCULATOR", calc.header,
	calc.header.right - 200, calc.top - 30, 200, 30)
title.font = largeFont
title.inverted = true

calc.display = Panel.make(calc, calc.left+160, calc.top-64, 420, 48)
calc.display.present = function
	gfx.fillRect self.left, self.bottom, self.width, self.height, "#666688"
	largeFont.printRight calc.displayStr, self.right - 4, self.bottom + 8, 2, self.style.displayColor
end function

calc.doAction = function(s)
	if s >= "0" and s <= "9" then
		if self.displayStr == "0" then self.displayStr = ""
		self.displayStr += s
	else if s == "Backspace" and self.displayStr then
		self.displayStr = calc.displayStr[:-1]
		if not self.displayStr then self.displayStr = "0"
	else if s == "Clear" then
		self.displayStr = "0"
		self.opA.text = ""
		self.operator.text = ""
		self.opA.present
		self.operator.present
	else if s == "=" then
		op = self.operator.text
		if not op then return
		valA = val(self.opA.text)
		valB = val(self.displayStr)
		result = valB
		if op == "+" then result = valA + valB
		if op == "-" then result = valA - valB
		if op == "*" then result = valA * valB
		if op == "/" then result = valA / valB
		if op == "^" then result = valA ^ valB
		if op == "%" then result = valA % valB
		if op == "and" then result = valA and valB
		if op == "or" then result = valA or valB
		if op == "not" then result = valA not valB
		self.displayStr = str(result)
	else
		self.opA.text = self.displayStr
		self.operator.text = s
		self.displayStr = "0"
		self.opA.present
		self.operator.present
	end if
	self.display.present
end function

calc.main = Frame.make(calc, null, 0, null, calc.height - 118)
calc.main.configure true, false, true, false

Gap.make calc.main.topPanel
InfoBlock.make "Calculation Log", calc.main.topPanel, null, null, 320
calc.main.topPanel.layout

b = Button.make("Backspace", calc.main.leftPanel, null, null, null, calc.style.buttonHeight)
b.action = function; calc.doAction self.caption; end function
b.key = char(8)

b = Button.make("Clear", calc.main.leftPanel, null, null, null, calc.style.buttonHeight)
b.action = function; calc.doAction self.caption; end function
b.key = char(1)	// (Home button, at least on Macs)

InfoBlock.make "", calc.main.leftPanel, null, null, null, calc.style.buttonHeight*2

b = Button.make("=", calc.main.leftPanel, null, null, null, calc.style.buttonHeight*3)
b.action = function; calc.doAction self.caption; end function
b.key = ["=", char(10), char(13), char(3)]

Gap.make calc.main.leftPanel

calc.opA = InfoBlock.make("", calc.main.leftPanel, null, null, null, calc.style.buttonHeight)
calc.operator = InfoBlock.make("", calc.main.leftPanel, null, null, null, calc.style.buttonHeight)
Gap.make calc.main.leftPanel
calc.main.leftPanel.layout

calc.main.setup = function
	y = self.topPanel.bottom - 72
	btns = ["789", "456", "123", " 0.", "+-*", "/^%", ["and","or","not"]]
	for row in btns.indexes
		for col in btns[row].indexes
			x = self.topPanel.left + 96*col
			if btns[row][col] == " " then continue
			if btns[row][col] == "0" then
				x = self.topPanel.left
				b = RoundButton.make(btns[row][col], calc, x, y, 84+96, 48)
			else
				b = RoundButton.make(btns[row][col], calc, x, y, 84, 48)
			end if
			b.action = function; calc.doAction self.caption; end function
		end for
		y = y - 60 - 24 * (row == 3)
	end for
end function
calc.main.setup


//----------------------------------------------------------------------
// Main Menu: a simple panel of buttons (and gaps) on the left side of the screen.
// Color of each button corresponds to the primary color of the UI it shows.
mainMenu = Panel.make(root, 0, 0, 144, 640)
mainMenu.style = new root.style
mainMenu.style.buttonHeight = 36
mainMenu.style.infoBlockColor = "#D0B0A0"
mainMenu.curMode = null

mainMenu.switchTo = function(modePanel)
	if self.curMode == modePanel then return
	if self.curMode then self.curMode.dismiss
	self.curMode = modePanel
	self.curMode.present
end function

// Mini-clock at the top
InfoBlock.make dateTime.now[-8:-3], mainMenu, null, null, null, 40
// Settings button
Button.make "Settings", mainMenu, null, null, null, mainMenu.style.buttonHeight
// ...gap...
Gap.make mainMenu
// Main buttons, one for each mode
Button.make("File Manager", mainMenu, null, null, null, mainMenu.style.buttonHeight).action = function
	mainMenu.switchTo fileManager
end function
Button.make("Clock", mainMenu, null, null, null, mainMenu.style.buttonHeight).action = function
	mainMenu.switchTo clock
end function
Button.make("Calculator", mainMenu, null, null, null, mainMenu.style.buttonHeight).action = function
	mainMenu.switchTo calc
end function
Button.make "News", mainMenu, null, null, null, mainMenu.style.buttonHeight
// ...gap...
Gap.make mainMenu
// Exit button at bottom
exitBtn = Button.make("Exit", mainMenu, null, null, null, mainMenu.style.buttonHeight)
exitBtn.action = function
	root.dismiss; root.destroy
	exit
end function
exitBtn.key = char(27)

events.eventLoop.onGotKey = function(k)
	Button.checkKey k
end function

mainMenu.layout
mainMenu.present
mainMenu.switchTo fileManager

events.eventLoop.run
