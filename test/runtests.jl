using WebWidgets, Blink
using Base.Test
imgs = []
w = Window()
test(img) = (push!(imgs, img); rand(0:9))

body!(w, drawnumber(test, resolution = (500, 500)))
# tools(w) # debug
