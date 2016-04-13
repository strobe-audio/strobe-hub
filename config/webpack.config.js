/* eslint-env node */
'use strict';

var path = require('path');
var precss       = require('precss');
var atImport = require("postcss-import")
var cssnext = require('postcss-cssnext');
var ExtractTextPlugin = require("extract-text-webpack-plugin");

function join(dest) { return path.resolve(__dirname, '..', dest); }
function web(dest) { return join('web/static/' + dest); }

console.log(web(''))
var config = [
  {
    entry: [
      web('css/app.css'),
    ],

    output: {
      path: join('priv/static/css'),
      filename: 'app.css',
    },

    module: {
      loaders: [
        {
          test:   /\.css$/,
          loader: ExtractTextPlugin.extract('style-loader', 'css!postcss'),
        },
      ],
    },
    plugins: [
      new ExtractTextPlugin('app.css'),
    ],
    postcss: function (webpack) {
      return [
        atImport({ addDependencyTo: webpack }),
        precss,
        cssnext,
      ];
    },
  },
  {
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
      noParse: /\.elm$/,
    },
  },
];

module.exports = config;
