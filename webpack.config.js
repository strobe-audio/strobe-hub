/* eslint-env node */
'use strict';

var path = require('path');

function join(dest) { return path.resolve(__dirname, dest); }
function web(dest) { return join('web/static/' + dest); }

console.log(web(''))
var config = {
  entry: [
    web('js/app.js'),
  ],

  output: {
    path: join('priv/static'),
    filename: 'js/app.js',
  },

  resolve: {
    modulesDirectories: ['node_modules'],
    extensions: ['', '.js', '.elm'],
    root: [web(''), web('js'), web('elm')],
  },

  module: {
    loaders: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        loader: 'babel-loader',
        // plugins: ['transform-es2015-modules-systemjs'],
        query: {
          presets: ['es2015'],
        },
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: 'elm-webpack',
      },
    ],
    noParse: /\.elm$/
  },
};

module.exports = config;
