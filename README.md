# MSc_Data-Science
This repository contains the code used for my Masters' Thesis: Counting objects in ecological images.
This repository can be used to:
   1. Estimate the number of objects in aerial images using a Shiny web application tool. This was developed to estimate counts of seabird coloniies in aerial images. However,       it can be applied to other aerial images.
   2. Train deep convolutional neural networks to detect and count objects using the YOLOv3 algorithm. This was developed to detect and count jellyfish, fish and school of fish in       images that were extracted from animal-borne videos. 

# Blob Counter Shiny Application

1. You will need to install R and R Studio in order to use the code provided.

2. You will need to install the following packages in R:
   - [x] install.packages("DT")
   - [x] install.packages("imager")
   - [x] install.packages("maptools")
   - [x] install.packages("plotKML")
   - [x] install.packages("raster")
   - [x] install.packages("shiny")
   - [x] install.packages("shinyjs")
   - [x] install.packages("sp")
   - [x] install.packages("spatstat")
   
3. The cheat sheet depicted below will guide you on how to use the web-application. To fully understand how to use the cropping functionality, refer to
   [GitHub](https://jfiksel.github.io/2017-02-26-cropping_images_with_a_shiny_app/) 
   
    ![Alt Text](https://github.com/Nakkita/MSc_Data-Science/blob/main/Blob%20Counter%20Shiny%20Application/webapp.png)
    
1   - Upload image for cropping. This is to isolate objects of interest as best as possible for better count estimates.

A/B - Options to pause or reset cropping back to original.

2   - Crop image.

3   - Download your cropped image (example of cropped image shown on the right labelled 3).

C   - If you do not want to crop your image, you can simply upload your original image here and bypass the cropping step. If you have cropped your image, upload it here for the       next steps.

4   - Greyscales the image.

D   - These are parameter sliders. You can slide across this to choose a parameter setting of your choice.

5/6 - Will binarize and blur your image, respectively, based on the parameter setting chosen and will dynamically update the image on the right.

Note: The binarizing step done to make sure that each animal in the image is clearly distinct from each other and the blurring step is to ensure that the pixels representing individual animals represent a blob. The degree at which you choose to binarize and blur the image determine how good your final estimated result will be. 

7   - Choose a threshold for the blob detection algorithm (slider above). A generally good threshold is 99 or 98. Click to get final estimated count. 
      Note: In this step the Determinant of Hessian algorithm is applied to detect the blobs in the image.

8   - You can choose to view the result of step 7 on the original image uploaded.

9   - You can download the final result.

An example of the downloaded final result is shown below.

![Alt Text](https://github.com/Nakkita/MSc_Data-Science/blob/main/Blob%20Counter%20Shiny%20Application/final%20downloaded%20image%20example.png)

# YOLOv3 Detection

- The data used in my dissertation are images extracted from animal-borne videos. A sample of the test set is provided under images.

- The YOLOv3 architecture configuration file used is `YOLOv3_model.cfg`  

- The Google Colab Notebook (`Object detection YOLOv3.ipynb`) provides the code used to train the YOLOv3 convolutional network. This code was adapted from https://github.com/theAIGuysCode/YOLOv4-Cloud-Tutorial

- A youtube video tutorial by theAIGuy outlines detailed steps to be followed to train your own custom YOLOv3 object detector
https://www.youtube.com/watch?v=10joRJt39Ns&t=1274s

## Final Model Weights

The final model weights: 

- After applying the model on a test set, the following file is created `result.txt`

- In my dissertation, I processed the detection results using the python file `Detection and counting.ipynb`. This code preprocesses the result.txt file into individual text files for each image that contain the class, confidence score, bounding box coorindates. Thereafter, this information is applied on the respective images. The confidence threshold are adjusted in the code to only produce detections of a certain threshold per class. Each resultant image shows the detections and counts per class. 

- Sample detections on the test sample are found under images.









