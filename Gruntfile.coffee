module.exports = (grunt) ->
	# Project configuration.
	grunt.initConfig
		pkg: grunt.file.readJSON('package.json')
		regarde:
			module:
				files: ["_src/**/*.coffee"]
				tasks: [ "coffee:changed" ]
			
		coffee:
			changed:
				expand: true
				cwd: '_src'
				src:	[ '<% print( _.first( ((typeof grunt !== "undefined" && grunt !== null ? (_ref = grunt.regarde) != null ? _ref.changed : void 0 : void 0) || ["_src/nothing"]) ).slice( "_src/".length ) ) %>' ]
				# template to cut off `_src/` and throw on error on non-regrade call
				# CF: `_.first( grunt?.regarde?.changed or [ "_src/nothing" ] ).slice( "_src/".length )
				dest: ''
				ext: '.js'

			base:
				expand: true
				cwd: '_src',
				src: ["**/*.coffee"]
				dest: ''
				ext: '.js'

		clean:
			base:
				src: [ "lib", "test" ]

		includereplace:
			pckg:
				options:
					globals:
						version: "<%= pkg.version %>"

					prefix: "@@"
					suffix: ''

				files:
					"index.js": ["index.js"]

		
		mochacli:
			options:
				require: [ "should" ]
				reporter: "spec"
				bail: false
				timeout: 3000
				slow: 3

			main:
				src: [ "test/main.js" ]
				options:
					env: 
						severity_rsmqworker: "warning"
		
		
		docker:
			serverdocs:
				expand: true
				src: ["_src/**/*.coffee", "README.md"]
				dest: "_docs/"
				options:
					onlyUpdated: false
					colourScheme: "autumn"
					ignoreHidden: false
					sidebarState: true
					exclude: false
					lineNums: true
					js: []
					css: []
					extras: []
		

	# Load npm modules
	grunt.loadNpmTasks "grunt-regarde"
	grunt.loadNpmTasks "grunt-contrib-coffee"
	grunt.loadNpmTasks "grunt-contrib-clean"
	grunt.loadNpmTasks "grunt-mocha-cli"
	grunt.loadNpmTasks "grunt-include-replace"
	grunt.loadNpmTasks "grunt-docker"

	# just a hack until this issue has been fixed: https://github.com/yeoman/grunt-regarde/issues/3
	grunt.option('force', not grunt.option('force'))
	
	# ALIAS TASKS
	grunt.registerTask "watch", "regarde"
	grunt.registerTask "default", "build"
	grunt.registerTask "docs", "docker"
	grunt.registerTask "clear", [ "clean:base" ]
	grunt.registerTask "test", [ "build", "mochacli:main" ]

	# build the project
	grunt.registerTask "build", [ "clear", "coffee:base", "includereplace" ]
	grunt.registerTask "build-dev", [ "clear", "coffee:base", "docs", "test" ]