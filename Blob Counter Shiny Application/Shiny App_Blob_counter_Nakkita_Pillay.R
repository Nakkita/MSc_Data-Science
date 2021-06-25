library(imager)
library(DT)

library(shinyjs)


ui<- fluidPage(
  titlePanel("Image Blob Counter"),
  useShinyjs(),
  sidebarLayout(
    sidebarPanel(
      fileInput("file1", "Choose Image",
                accept=c(".png",
                         ".jpg")),
      textInput("imgName", "Image Name", ""),
      actionButton("selectForeground", "Begin Crop"),
      p("Click the button to begin cropping the image"),
      actionButton("pauseCropping", "Pause Cropping"),
      p("Click the button to pause background cropping"),
      actionButton("resetCropping", "Reset Cropping"),
      p("Click the button to reset background cropping"),
      actionButton("cropBackground", "Crop Image"),
      p("Click after you have cropped out the background"),
      actionButton("downloadImage", "Download Image"),
      p("Click to download the cropped image"),
      fileInput("file2", "Choose Image",
                accept=c(".png",
                         ".jpg")),
      actionButton(inputId = "xx", label="Click to greyscale Image"),
      sliderInput(inputId = "yy",
                  label="Choose parameter to Binarize Image",
                  min = 0,
                  max = 1,
                  value=0.2,
                  step=0.01),
      actionButton(inputId = "go", label="Click to Binarize Image"),
      sliderInput(inputId = "zz",
                  label="Choose parameter to Blur Image",
                  min = 0,
                  max = 50,
                  value=0,
                  step=0.1),
      actionButton(inputId = "go2", label="Click to Blurr Image"),
      sliderInput(inputId = "aa",
                  label="Choose parameter to get number of blurred centres",
                  min = 0,
                  max = 100,
                  value=0,
                  step=1),
      actionButton(inputId = "go3", label="Click to get blurred centres"),
      actionButton(inputId="go4", label="Click to view on original image"),
      actionButton(inputId="downloadImage2", label="Download image final image")
    ),
    mainPanel(
      plotOutput("plot1", click="plot1_click",
                 dblclick = "plot1_dblclick",
                 brush = brushOpts(
                   id = "plot1_brush",
                   resetOnNew = TRUE
                 )),
      plotOutput("plot2", click="plot2_click",
                 dblclick = "plot2_dblclick",
                 brush = brushOpts(
                   id = "plot2_brush",
                   resetOnNew = TRUE
                 )),
      textOutput("text"),
      plotOutput("plot3", click="plot3_click",
                 dblclick = "plot3_dblclick",
                 brush = brushOpts(
                   id = "plot3_brush",
                   resetOnNew = TRUE
                 )),
      textOutput("text2")
      
    )
  )
)

library(shiny)
library(shinyjs)
library(spatstat)
library(sp)
library(plotKML)
library(maptools)
library(raster)
library(DT)
server<-function(input, output, session) {
 
  ### Function to read in images
  read.image <- function(image.file){
    im <- load.image(image.file)
    if(dim(im)[4] > 3){
      im <- imappend(channels(im, 1:3), 'c')
    }
    im
  }
  
  ### Function to select points
  ### Returns a mask that's the same dimension as the image
  ### With a 1 if that point is to be included
  select.points <- function(im, x, y){
    if(is.null(x) | is.null(y)){
      mask <- matrix(1L, nrow=nrow(im), ncol=ncol(im))
    }else{
      xy<-cbind(x,y)
      xy<-as.data.frame(xy)
      coordinates(xy)=c("x","y")
      pnts<-vect2rast(xy)
      poly <- owin(poly=list(x=x, y=y), check=F)
      SpP<- as(poly,  "SpatialPolygons")
      attr  =  data.frame(a=1,  b=1)
      SrDf  =  SpatialPolygonsDataFrame(SpP,  attr)
      rast <- vect2rast(SrDf,cell.size=1)
      r <- raster(rast)
      crop <- coordinates(r)[!is.na(values(r)),]
      crop <- as.data.frame(crop)
      mask <- matrix(0L, nrow=nrow(im), ncol=ncol(im))
      for(x.coord in unique(crop$x)){
        t <- crop[crop$x==x.coord,]
        mask[t$x, t$y] <- 1
      }
    }
    mask
  }
  
  
  ### Makes all points in image that have a 0 in the mask white
  removePoints <- function(im, mask){
    im[mask==0] <- 1
    im
  }
  
  ### Generic function for plotting the image
  app.plot <- function(im, clicks.x = NULL, clicks.y = NULL, lineslist = NULL){
    if(is.null(im)){
      return(NULL)
    }
    if(is.null(ranges$x) | is.null(ranges$y)){
      #plot(paw, xaxt='n', yaxt='n', ann=FALSE)
      plot(im, xaxt='n', yaxt='n', ann=FALSE)
    }else{
      plot(im, xaxt='n', yaxt='n', ann=FALSE, xlim=ranges$x,  ylim=c(ranges$y[2], ranges$y[1]))
    }
    if(length(clicks.x) > 1){
      lines(c(clicks.x, clicks.x[1]), c(clicks.y, clicks.y[1]), col='red')
    }
    if(!is.null(lineslist)){
      for(i in 1:length(lineslist)){
        x <- lineslist[[i]][[1]]
        y <- lineslist[[i]][[2]]
        lines(c(x, x[1]), c(y, y[1]), col='red')
      }
    }
  }
  
  ### Set ranges for zooming
  ranges <- reactiveValues(x = NULL, y = NULL)
  
  ### Code to zoom in on brushed area when double clicking for plot 1
  observeEvent(input$plot1_dblclick, {
    brush <- input$plot1_brush
    if (!is.null(brush)) {
      ranges$x <- c(brush$xmin, brush$xmax)
      ranges$y <- c(brush$ymin, brush$ymax)
      
    } else {
      ranges$x <- NULL
      ranges$y <- NULL
    }
  })
  
  v <- reactiveValues(
    originalImage = NULL,
    croppedImage = NULL,
    imgMask = NULL,
    imgclick.x = NULL,
    imgclick.y = NULL,
    crop.img = FALSE,
    imageName = NULL
  )
  
  ### Read in image
  ### Automatically set image name to file name
  observeEvent(input$file1, {
    v$originalImage <- read.image(input$file1$datapath)
    v$croppedImage = NULL
    v$imgMask = NULL
    v$imgclick.x = NULL
    v$imgclick.y = NULL
    v$crop.img = FALSE
    v$imageName <- gsub("(.jpg|.png)","", input$file1$name)
    updateTextInput(session, inputId = "imgName", label = NULL, value = v$imageName)
    output$plot1 <- renderPlot({
      app.plot(v$originalImage,v$imgclick.x, v$imgclick.y)
    })
  })
  
  observeEvent(input$imgName, {
    v$imageName <- input$imgName
  })
  
  # Handle clicks on the plot for tracing foreground
  observeEvent(input$selectForeground, {
    v$crop.img <- TRUE
    disable("selectForeground")
    enable("pauseCropping")
    enable("resetCropping")
    enable("cropBackground")
  })
  
  ### Pause cropping
  observeEvent(input$pauseCropping, {
    v$crop.img <- FALSE
    disable("pauseCropping")
    enable("selectForeground")
    enable("resetTracePaw")
    enable("cropBackground")
  })
  
  
  ## Reset cropping
  observeEvent(input$resetCropping, {
    v$croppedImage <- NULL
    v$imgMask <- NULL
    v$crop.img <- FALSE
    v$imgclick.x  <- NULL
    v$imgclick.y <- NULL
    enable("pauseCropping")
    enable("selectForeground")
    disable("resetTracePaw")
    enable("cropBackground")
    output$plot1 <- renderPlot({
      app.plot(v$originalImage,v$imgclick.x, v$imgclick.y)
    })
  })
  
  
  observeEvent(input$cropBackground,{
    if(is.null(v$imgclick.x) | is.null(v$imgclick.y)){
      v$croppedImage <- v$originalImage
      v$imgMask <- select.points(v$originalImage, v$imgclick.x, v$imgclick.y)
    }else{
      v$imgMask <- select.points(v$originalImage, v$imgclick.x, v$imgclick.y)
      v$croppedImage <- removePoints(v$originalImage, v$imgMask)
      v$crop.img <- FALSE
      v$imgclick.x  <- NULL
      v$imgclick.y <- NULL
      enable("pauseCropping")
      enable("selectForeground")
      enable("resetTracePaw")
      disable("cropBackground")
    }
    output$plot1 <- renderPlot({
      app.plot(v$croppedImage)
    })
  })
  
  observeEvent(input$downloadImage, {
    imager::save.image(v$croppedImage, "croppedImage.jpeg")
  })
  
  ### Keep track of click locations if tracing paw or tumor 
  observeEvent(input$plot1_click, {
    # Keep track of number of clicks for line drawing
    if(v$crop.img){
      v$imgclick.x <- c(v$imgclick.x, round(input$plot1_click$x))
      v$imgclick.y <- c(v$imgclick.y, round(input$plot1_click$y))
    }
  })
  
  ### Original Image
  output$plot1 <- renderPlot({
    app.plot(v$originalImage,v$imgclick.x, v$imgclick.y)
  })
  #######################################################################
  ### Function to read in images
  read.image1 <- function(image.file){
    im <- load.image(image.file)
    if(dim(im)[4] > 3){
      im <- imappend(channels(im, 1:3), 'c')
    }
    im
  }
  
  app.plot1 <- function(im, pntx=NULL, pnty=NULL, bg=NULL){
    if(is.null(im)){
      return(NULL)
    }
    if(is.null(pntx) | is.null(pnty)){
      par(bg=bg)
      plot(im, xaxt='n', yaxt='n', ann=FALSE)
    }else {
      par(bg=bg)
      plot(im, xaxt='n', yaxt='n', ann=FALSE)
      points(pntx, pnty, pch=1, col="red")
      
    }
    
    
  }
  
  
  j <- reactiveValues(
    originalImage1 = NULL,
    originalImage2=NULL,
    originalImage3=NULL
  )
  
  ### Read in image
  ### Automatically set image name to file name
  observeEvent(input$file2, {
    j$originalImage1 <- read.image1(input$file2$datapath)
    pntx=NULL
    pnty=NULL
    output$plot2 <- renderPlot({
      app.plot1(j$originalImage1,  pntx, pnty)
      
    })
  })
  
  ### Read in image
  ### Automatically set image name to file name
  observeEvent(input$xx, {
   
    j$originalImage2 <- grayscale(j$originalImage1)
    
    pntx=NULL
    pnty=NULL
    output$plot2 <- renderPlot({
      app.plot1(j$originalImage2,  pntx, pnty)
    })
  })
  
  observeEvent(input$go, {
    x<-as.numeric(input$yy)
    binarized_image <- j$originalImage2 < x
    j$originalImage21 <-1 - binarized_image
    pntx=NULL
    pnty=NULL
    output$plot2 <- renderPlot({
      app.plot1(j$originalImage21,  pntx, pnty)
    })
  })
  
  observeEvent(input$go2, {
    xx<-as.numeric(input$zz)
    blurry_patch <- isoblur(j$originalImage21, xx)
    j$originalImage3 <- 1 - blurry_patch
    pntx=NULL
    pnty=NULL
    output$plot2 <- renderPlot({
      app.plot1(j$originalImage3, pntx, pnty)
      
    })
  })
  
  
  observeEvent(input$go3, {
    get.centers <- function(im, thr)
    {
      dt <- imager::imhessian(im) %$% { xx*yy - xy^2 } %>% imager::threshold(thr)
      dt<-imager::label(dt)
      dt<-as.data.frame(dt) %>% subset(value>0) %>%
        dplyr::group_by(value) %>%
        dplyr::summarise(mx = mean(x), my = mean(y))
    }
    pntx=NULL
    pnty=NULL
    numberinput<-input$aa
    stringinput<-as.character(numberinput)
    centers <- get.centers(j$originalImage3, stringinput)
    pntx=centers$mx
    pnty=centers$my
    output$plot2 <- renderPlot({
      app.plot1(j$originalImage3, pntx, pnty)
    })
    count<-nrow(centers)
    
    output$text <- renderPrint({
      paste("The estimated count is:", count, collpase='\n') %>% cat()
    })
  })
  
  
  observeEvent(input$go3, {
    get.centers <- function(im, thr)
    {
      dt <- imager::imhessian(im) %$% { xx*yy - xy^2 } %>% imager::threshold(thr)
      dt<-imager::label(dt)
      dt<-as.data.frame(dt) %>% subset(value>0) %>%
        dplyr::group_by(value) %>%
        dplyr::summarise(mx = mean(x), my = mean(y))
    }
    pntx=NULL
    pnty=NULL
    numberinput<-input$aa
    stringinput<-as.character(numberinput)
    centers <- get.centers(j$originalImage3, stringinput)
    pntx=centers$mx
    pnty=centers$my
    output$plot2 <- renderPlot({
      app.plot1(j$originalImage3, pntx, pnty)
    })
    count<-nrow(centers)
    
    output$text <- renderPrint({
      paste("The estimated count is:", count, collpase='\n') %>% cat()
    })
  })
  
  observeEvent(input$go4, {
    get.centers <- function(im, thr)
    {
      dt <- imager::imhessian(im) %$% { xx*yy - xy^2 } %>% imager::threshold(thr)
      dt<-imager::label(dt)
      dt<-as.data.frame(dt) %>% subset(value>0) %>%
        dplyr::group_by(value) %>%
        dplyr::summarise(mx = mean(x), my = mean(y))
    }
    pntx=NULL
    pnty=NULL
    numberinput<-input$aa
    stringinput<-as.character(numberinput)
    centers <- get.centers(j$originalImage3, stringinput)
    pntx=centers$mx
    pnty=centers$my
    output$plot3 <- renderPlot({
      app.plot1(j$originalImage1, pntx, pnty)
      
      
    })
    
  })
  
  
  observeEvent(input$downloadImage2, {
      get.centers <- function(im, thr)
      {
        dt <- imager::imhessian(im) %$% { xx*yy - xy^2 } %>% imager::threshold(thr)
        dt<-imager::label(dt)
        dt<-as.data.frame(dt) %>% subset(value>0) %>%
          dplyr::group_by(value) %>%
          dplyr::summarise(mx = mean(x), my = mean(y))
      }
      pntx=NULL
      pnty=NULL
      numberinput<-input$aa
      stringinput<-as.character(numberinput)
      centers <- get.centers(j$originalImage3, stringinput)
      pntx=centers$mx
      pnty=centers$my
      count<-nrow(centers)
      words<-paste("Count", count)
      
      library(Cairo)
      Cairo(file="FinalImage.png",
            type="png",
            units="px", 
            width=1000, 
            height=800, 
            pointsize=12, 
            dpi="auto")
      #app.plot1(j$originalImage1, pntx, pnty) 
      plot(j$originalImage1) 
      points(pntx, pnty, col = 'red', pch = 1)
      #text(50,20,words, col='green', cex=1.2)
      
      ## When the device is off, file writing is completed.
      dev.off()
      output$text2 <- renderPrint({
        paste("Download complete")
      })
    
  })
  
 
  
  ### Original Image
  output$plot2 <- renderPlot({
    app.plot1(j$originalImage1, pntx, pnty)
  })
  


  
  ### Original Image
 # output$plot1 <- renderPlot({
   # app.plot(v$originalImage,v$imgclick.x, v$imgclick.y)
  #})
  
}

# Run the application
shinyApp(ui = ui, server = server)