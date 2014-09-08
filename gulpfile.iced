gutil = require('gulp-util')
gulp = require('gulp')
$ = require('gulp-load-plugins')()

gulp.task 'iced', ->
  gulp.src('./src/**/*.coffee')
    .pipe($.iced({bare: true})).on('error', gutil.log)
    .pipe(gulp.dest('./lib/'))

gulp.task 'default', ['iced']
