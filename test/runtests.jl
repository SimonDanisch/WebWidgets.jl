using WebWidgets, Blink, Colors, InteractNext
using Base.Test

app, img, num = drawandpredictnumber(brushsize = 15, use_slider = false, resolution = (200, 200))
num[]
img[]
app
app, img = drawnumber(brushsize = 6, use_slider = true)
app
Gray.(img[])
