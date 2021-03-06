class App extends React.Component
	constructor: (props) ->
		super props

		@state =
			system:
				display:
					brightness: 1
				sound:
					volume: .5
				battery:
					level: undefined
					charging: undefined
					env:
						manager: null
				storage:
					local:
						env:
							manager: null
							listeners:
								connected: []
					drive:
						env:
							manager: null
			personal:
				background:
					type: "image"
					imgSrc: "https://i.imgur.com/wOcQPsq.png"
					size: "cover"
				taskbar:
					location: "bottom"
			apps:
				app:
					list: []
					env:
						tasks: []

	set: (path, val, nextTick) ->
		@setState objectPathImmutable.set(@state, path, val), nextTick
		return

	update: (path, updater, nextTick) ->
		@setState objectPathImmutable.update(@state, path, updater), nextTick
		return

	push: (path, val, nextTick) ->
		@setState objectPathImmutable.push(@state, path, val), nextTick
		return

	del: (path, nextTick) ->
		@setState objectPathImmutable.del(@state, path), nextTick
		return

	assign: (path, obj, nextTick) ->
		@setState objectPathImmutable.assign(@state, path, val), nextTick
		return

	insert: (path, val, pos, nextTick) ->
		@setState objectPathImmutable.insert(@state, path, val, pos), nextTick
		return

	systemDisplaySetBrightness: (val) ->
		@set "system.display.brightness", val unless isNaN val = +val
		return

	systemSoundGetIconName: (volume = @state.system.sound.volume) ->
		if volume is 0
			"volume-off"
		else if volume < .5
			"volume-down"
		else
			"volume-up"

	systemSoundSetVolume: (val) ->
		@set "system.sound.volume", val unless isNaN val = +val
		return

	systemBatteryGetIcons8Name: (level) ->
		if level is undefined
			"battery-unknown"
		else if level is 0
			"empty-battery"
		else if level < 1 / 3
			"low-battery"
		else if level < 2 / 3
			"medium-battery"
		else if level < 1
			"high-battery"
		else
			"full-battery"

	systemStorageGetFile: (dir, path, success, error) ->
		dir.getFile path, create: no, success, error
		return

	systemStorageCreateFile: (dir, path, success, error) ->
		dir.getFile path, create: yes, success, error
		return

	systemStorageWriteFile: (file, data, dataType, success, error) ->
		file.createWriter(
			(writer) =>
				blob = new Blob [data], {dataType}
				writer.onwriteend = success
				writer.onerror = error
				writer.write blob
				return
			error
		)
		return

	systemStorageReadFile: (file, returnType = "text", success, error) ->
		file.file(
			(file) =>
				reader = new FileReader
				reader.onload = =>
					success reader.result
					return
				reader.onerror = (err) =>
					error err
					return
				reader["readAs" + returnType[0].toUpperCase() + returnType[1..]]? file
				return
			error
		)
		return

	systemStorageDeleteFile: (file, success, error) ->
		file.remove success, error
		return

	systemStorageListEntries: (dir, success, error) ->
		reader = dir.createReader()
		entries = []
		fetchEntries = =>
			reader.readEntries(
				(result) =>
					if result.length
						entries = [...entries, ...result]
						fetchEntries()
					else
						success entries.sort().reverse()
				error
			)
			return
		fetchEntries()
		return

	systemStorageLocalConnect: (cb) ->
		if @state.system.storage.local.env.manager
			cb @state.system.storage.local.env.manager
		else
			@push "system.storage.local.env.listeners.connected", cb
		cb

	systemStorageLocalDisconnect: (cbRef) ->
		@set "system.storage.local.env.listeners.connected",
			@state.system.storage.local.env.listeners.connected.filter (cbFn) =>
				cbFn isnt cbRef
		return

	appsAppRun: (parent, path, propsData) ->
		fetch path
			.then (res) => res.text()
			.then (text) =>
				Component = eval Babel.transform(
					CoffeeScript.compile text, bare: yes
					presets: ["react"]
					plugins: ["syntax-object-rest-spread"]
				).code
				task =
					name: Component.name
					title: Component.modal?.title
					path: path
					pid: _.random 9e9
					parent: parent
				task.jsx =
					<Modal
						key={task.pid}
						task={task}
						propsData={propsData}
					>
						{Component}
					</Modal>
				app.push.call parent, "apps.app.env.tasks", task
				return
		return

	appsAppKill: (task) ->
		for taskChild from task.modal.state.apps.app.env.tasks
			taskChild.modal.close()
		@set.call task.modal, "isOpen", no
		setTimer 100, =>
			@set.call task.parent, "apps.app.env.tasks",
				_.filter task.parent.state.apps.app.env.tasks, (taskChild) =>
					taskChild isnt task
			return
		return

	componentWillMount: ->
		app = @

		navigator.getBattery?().then (battery) =>
			battery.onlevelchange = =>
				@set "system.battery.level", battery.level
				return
			battery.onchargingchange = =>
				@set "system.battery.charging", battery.charging
				return
			@set "system.battery.env.manager", battery
			battery.onlevelchange()
			battery.onchargingchange()

		navigator.webkitPersistentStorage?.requestQuota 1024 * 1024 * 4,
			(size) =>
				window.webkitRequestFileSystem? Window.PERSISTENT, size,
					(fs) =>
						@set "system.storage.local.env.manager", fs, =>
							for cbFn from @state.system.storage.local.env.listeners.connected
								cbFn @state.system.storage.local.env.manager
						return
					(err) =>
						return
				return
			(err) =>
				return
		return

	componentDidMount: ->
		@appsAppRun @, "/programs/FileManager/index.cjsx"
		return

	rootClass: ->
		backgroundImage: "url(#{@state.personal.background.imgSrc})"
		backgroundSize: @state.personal.background.size
		backgroundPosition: "50%"
		backgroundRepeat: "no-repeat"

	rootNavbarClass: ->
		[@state.personal.taskbar.location]: 0

	render: ->
		<div className="App" style={@rootClass()}>
			{@state.apps.app.env.tasks.map (task) => task.jsx}
			<Navbar
				className="App-taskbar bp3-dark"
				style={@rootNavbarClass()}
			>
				<NavbarGroup align="left">
					<TaskbarHome/>
					<NavbarDivider/>
				</NavbarGroup>
				<NavbarGroup align="right">
					<NavbarDivider/>
					<ButtonGroup>
						<TaskbarSound/>
						<TaskbarBattery/>
						<TaskbarDatetime/>
						<TaskbarAction/>
					</ButtonGroup>
				</NavbarGroup>
			</Navbar>
			<div
				className="App-brightness"
				style={opacity: 1 - @state.system.display.brightness}
			></div>
		</div>
