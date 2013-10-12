coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/util.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

@Type.FAIRY  = Type.FAIRY  = 17
@Type["???"] = Type["???"] = 18

typeChart = [
  # Nor Fir Wat Ele Gra Ice Fig Poi Gro Fly Psy Bug Roc Gho Dra Dar Ste Fai, ???
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, .5,  0,  1,  1, .5,  1,  1 ], # Nor
  [  1, .5, .5,  1,  2,  2,  1,  1,  1,  1,  1,  2, .5,  1, .5,  1,  2,  1,  1 ], # Fir
  [  1,  2, .5,  1, .5,  1,  1,  1,  2,  1,  1,  1,  2,  1, .5,  1,  1,  1,  1 ], # Wat
  [  1,  1,  2, .5, .5,  1,  1,  1,  0,  2,  1,  1,  1,  1, .5,  1,  1,  1,  1 ], # Ele
  [  1, .5,  2,  1, .5,  1,  1, .5,  2, .5,  1, .5,  2,  1, .5,  1, .5,  1,  1 ], # Gra
  [  1, .5, .5,  1,  2, .5,  1,  1,  2,  2,  1,  1,  1,  1,  2,  1, .5,  1,  1 ], # Ice
  [  2,  1,  1,  1,  1,  2,  1, .5,  1, .5, .5, .5,  2,  0,  1,  2,  2, .5,  1 ], # Fig
  [  1,  1,  1,  1,  2,  1,  1, .5, .5,  1,  1,  1, .5, .5,  1,  1,  0,  2,  1 ], # Poi
  [  1,  2,  1,  2, .5,  1,  1,  2,  1,  0,  1, .5,  2,  1,  1,  1,  2,  1,  1 ], # Gro
  [  1,  1,  1, .5,  2,  1,  2,  1,  1,  1,  1,  2, .5,  1,  1,  1, .5,  1,  1 ], # Fly
  [  1,  1,  1,  1,  1,  1,  2,  2,  1,  1, .5,  1,  1,  1,  1,  0, .5,  1,  1 ], # Psy
  [  1, .5,  1,  1,  2,  1, .5, .5,  1, .5,  2,  1,  1, .5,  1,  2, .5, .5,  1 ], # Bug
  [  1,  2,  1,  1,  1,  2, .5,  1, .5,  2,  1,  2,  1,  1,  1,  1, .5,  1,  1 ], # Roc
  [  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  1,  1,  2,  1, .5,  1,  1,  1 ], # Gho
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  1, .5,  0,  1 ], # Dra
  [  1,  1,  1,  1,  1,  1, .5,  1,  1,  1,  2,  1,  1,  2,  1,  1,  1, .5,  1 ], # Dar
  [  1, .5, .5, .5,  1,  2,  1,  1,  1,  1,  1,  1,  2,  1,  1,  1, .5,  2,  1 ], # Ste
  [  1, .5,  1,  1,  1,  1,  2, .5,  1,  1,  1,  1,  1,  1,  2,  2, .5,  1,  1 ], # Fai
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1 ]  # ???
]
