This is an edit of Apple's [LazyTableImages](http://developer.apple.com/library/ios/#samplecode/LazyTableImages/Introduction/Intro.html) sample project in which I attempt to remedy a few limitations in their implementation, namely:

1. Apple's original implementation won't try to retrieve the images until the scrolling finished. I understand why they chose to do that (probably don't want to retrieve images that might be scrolling away), but this causes the images to appear more slowly than necessary.

2. It does not constrain the number of concurrent requests to some reasonable number. Yes, `NSURLConnection` will automatically freeze requests until the maximum number of requests falls to some reasonable number, but in a worst case scenario, you can actually have requests time out, as opposed to simply queueing properly.

3. Once it starts to download the image, it won't cancel it even if the cell subsequently scrolls off of the screen.

The initial commit of this project is Apple's original project, so if you look at the change history, my edits should be apparent. The net effect is that it simplifies the implementation and employs `NSOperationQueue` to constrain the number of concurrent requests.