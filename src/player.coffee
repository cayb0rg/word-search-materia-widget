Namespace('WordSearch').Engine = do ->
	# reference to qset
	_qset = null

	# reference to canvas drawing board
	_canvas	 = null
	_context = null

	# track the click locations
	_clickStart = x: 0, y: 0
	_clickEnd = x: 0, y: 0
	_isMouseDown = false

	# track puzzle information
	_letterArray = []
	_solvedRegions = []

	# Called by Materia.Engine when your widget Engine should start the user experience.
	start = (instance, qset, version = '1') ->
		# local variable contexts
		_qset = qset

		# set title
		document.getElementById('title').innerHTML = instance.name

		# get canvas context
		_canvas = document.getElementById('canvas')
		if !_canvas.getContext?
			document.querySelector('.error-notice-container')[0].style.display = 'block'
			return

		_context = _canvas.getContext('2d')

		if _qset.items[0] and _qset.items[0].items?
			_qset.items = _qset.items[0].items

		# set up the player UI
		html = ""
		n = 0
		for question in _qset.items
			html += "<div id='term_" + n + "'>" + (question.questions[0].text or question.answers[0].text) + "</div>"
			n++

		# renders letters
		WordSearch.Puzzle.drawBoard(_context, _qset, _clickStart, _clickEnd)

		# add term html to the sidebar
		document.getElementById('terms').innerHTML = html

		# generate letter arrays
		x = 0
		y = 1
		_letterArray[y] = []

		for n in [0.._qset.options.spots.length]
			letter = _qset.options.spots.substr(n,1)

			_letterArray[y].push letter

			x++
			if (x >= _qset.options.puzzleWidth)
				x = 0
				y++
				_letterArray[y] = []

		# attach document listeners
		document.addEventListener('touchstart', _mouseDownEvent, false)
		document.addEventListener('touchend', _mouseUpEvent, false)
		document.addEventListener('touchmove', _mouseMoveEvent, false)
		document.addEventListener('mouseup', _mouseUpEvent, false)
		document.addEventListener('mousedown', _mouseDownEvent, false)
		document.addEventListener('mousemove', _mouseMoveEvent, false)
		document.addEventListener('MSPointerUp', _mouseUpEvent, false)
		document.addEventListener('MSPointerMove', _mouseMoveEvent, false)
		document.onselectstart = (e) -> false

		document.getElementById('checkbtn').addEventListener 'click', _confirmDone

		# once everything is drawn, set the height of the player
		Materia.Engine.setHeight()

	# when a term is mouse downed
	_mouseDownEvent = (e) ->
		if not e?
			e = window.event

		# don't scroll the page on an iPad
		if e.preventDefault()
			e.preventDefault()

		if e.touches
			e = e.touches[0]

		_isMouseDown = true
		_clickStart = x: e.clientX, y: e.clientY

		window.focus()

	# when we let go of a term
	_mouseUpEvent = (e) ->
		if e.changedTouches
			e = e.changedTouches[0]
		_clickEnd = x: e.clientX, y: e.clientY
		_isMouseDown = false

		gridStart = WordSearch.Puzzle.getGridFromXY _clickStart
		gridEnd = WordSearch.Puzzle.getGridFromXY _clickEnd

		n = 0

		# get the vector from the mouse, and make it 45 degrees
		vector = WordSearch.Puzzle.correctDiagonalVector WordSearch.Puzzle.getGridFromXY(_clickStart), WordSearch.Puzzle.getGridFromXY(_clickEnd)

		alreadySolved = WordSearch.Puzzle.solvedRegions.length

		_findSolvedInVector vector
		totalSolved = WordSearch.Puzzle.solvedRegions.length

		_clickStart = _clickEnd = x: 0, y: 0
		WordSearch.Puzzle.drawBoard(_context, _qset, _clickStart, _clickEnd)

		# prevent iPad/etc from scrolling
		e.preventDefault()
		false

	_findSolvedInVector = (vector) ->
		gridStart = vector.start
		gridEnd = vector.end

		x = gridStart.x
		y = gridStart.y

		position = _qset.options.wordLocations.split(",")

		for i in [0..position.length-1]
			word = ""

			while 1
				if not _letterArray[y]?[x]?
					break

				word += _letterArray[y][x]

				if y == gridEnd.y and x == gridEnd.x
					break
				if x < gridEnd.x
					x++
				if y < gridEnd.y
					y++
				if x > gridEnd.x
					x--
				if y > gridEnd.y
					y--
				n++
				if n > 1000
					break

			# check the word
			solved = 0
			n = 0
			word = word.toLowerCase()
			for question in _qset.items
				if question.solved
					n++
					continue
				answer = question.answers[0].text.replace(/\s/g,'').toLowerCase()
				if answer == word or answer == word.split("").reverse().join("")
					question.solved = true
					document.getElementById('term_' + n).classList.add 'strike'

					WordSearch.Puzzle.solvedRegions.push
						x: gridStart.x
						y: gridStart.y
						endx: gridEnd.x
						endy: gridEnd.y

				if question.solved
					solved++

				n++

			if solved == _qset.items.length
				_submitAnswers()
			else
				return solved

	# if the mouse is down, render the board every time the position updates
	_mouseMoveEvent = (e) ->
		if e.touches
			e = e.touches[0]
		_clickEnd = x: e.clientX, y: e.clientY
		WordSearch.Puzzle.drawBoard(_context, _qset, _clickStart, _clickEnd, _isMouseDown)

	# show the "are you done" warning
	_confirmDone = ->
		document.getElementById('alertbox').classList.add 'show'
		document.getElementById('backgroundcover').classList.add 'show'
		document.querySelector('#alertbox #okbtn').addEventListener 'click', () ->
			_hideAlert()
			_submitAnswers()
		document.querySelector('#alertbox #cancelbtn').addEventListener 'click', () ->
			_hideAlert()

	# hide it
	_hideAlert = ->
		document.getElementById('alertbox').classList.remove 'show'
		document.getElementById('backgroundcover').classList.remove 'show'

	# submit every question and the placed answer to Materia for scoring
	_submitAnswers = ->
		for question in _qset.items
			# submit blank if its solved, otherwise submit the answer
			answer = if question.solved then question.answers[0].text else ''
			Materia.Score.submitQuestionForScoring question.id, answer
		Materia.Engine.end()

	#public
	manualResize: true
	start: start
