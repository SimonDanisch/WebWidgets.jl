using WebWidgets, Blink, Colors, InteractNext
using Base.Test

app, img, num = drawandpredictnumber(brushsize = 15, use_slider = false, resolution = (300, 300))
num[]
Gray.(img[])
app
app, img = drawnumber(brushsize = 16,  use_slider = true, resolution = (300, 300))
app
Gray.(img[])
