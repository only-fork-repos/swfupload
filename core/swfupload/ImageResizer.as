﻿/*
 * http://code.google.com/p/sync-to-async/ -- Apache 2.0 License
 */

// FIXME -- handler errors for the loader and file_reference objects

package  
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filters.BitmapFilter;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.BlurFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileReference;
	import flash.utils.ByteArray;
	
	/*
	Technique adapted from Kun Janos (http://kun-janos.ro/blog/?p=107)
	*/
	public class ImageResizer extends EventDispatcher
	{
		private var file:FileItem = null;
		private var targetWidth:Number = 0;
		private var targetHeight:Number = 0;
		private var newWidth:Number = 1;
		private var newHeight:Number = 1;
		private var encoder:Number = ImageResizer.JPEGENCODER;
		private var quality:Number = 100;
		
		public static const JPEGENCODER:Number = -1;
		public static const PNGENCODE:Number = -2;
		
		public function ImageResizer(file:FileItem, targetWidth:Number, targetHeight:Number, encoder:Number, quality:Number = 100) {
			this.file = file;
			this.targetHeight = targetHeight;
			this.targetWidth = targetWidth;
			this.encoder = encoder;
			this.quality = quality;
			
			if (this.encoder != ImageResizer.JPEGENCODER && this.encoder != ImageResizer.PNGENCODE) {
				this.encoder = ImageResizer.JPEGENCODER;
			}
			if (this.quality < 0 || this.quality > 100) {
				this.quality = 100;
			}
		}
		
		public function ResizeImage():void {
			try {
				this.file.file_reference.addEventListener(Event.COMPLETE, this.fileLoad_Complete);
				this.file.file_reference.load();
			} catch (ex:Error) {
				this.file.file_reference.removeEventListener(Event.COMPLETE, this.fileLoad_Complete);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Loading from file reference: " + ex.message));
			}
			this.file = null;
		}
		
		private function fileLoad_Complete(event:Event):void {
			try {
				event.target.removeEventListener(Event.COMPLETE, this.fileLoad_Complete);
				
				var loader:Loader = new Loader();
				
				// Load the image data, resizing takes place in the event handler
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.loader_Complete);
				
				loader.loadBytes(FileReference(event.target).data);
			} catch (ex:Error) {
				loader.removeEventListener(Event.COMPLETE, this.loader_Complete);
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Loading Loader" + ex.message));
				this.file = null;
			}
		}
		private function loader_Complete(event:Event):void {
			try {
				var bytes:ByteArray;
				
				event.target.removeEventListener(Event.COMPLETE, this.loader_Complete);

				var loader:Loader = Loader(event.target.loader);

				// Calculate the new image size
				var targetRatio:Number = this.targetWidth / this.targetHeight;
				var imgRatio:Number = loader.width / loader.height;
				this.newHeight = (targetRatio > imgRatio) ? this.targetHeight : Math.min(this.targetWidth / imgRatio, this.targetHeight);
				this.newWidth = (targetRatio > imgRatio) ? Math.min(imgRatio * this.targetHeight, this.targetWidth) : this.targetWidth;
				
				var resizedBmp:BitmapData = null;
				
				// Get the image data
				var bmp:BitmapData = Bitmap(loader.content).bitmapData;
				
				loader.unload();
				loader = null;

				// Blur it a bit if it is sizing smaller
				if (this.newWidth < bmp.width || this.newHeight <= bmp.height) {
					// Apply the blur filter that helps clean up the resized image result
					var blurMultiplier:Number = 1.15; // 1.25;
					var blurXValue:Number = Math.max(1, bmp.width / this.newWidth) * blurMultiplier;
					var blurYValue:Number = Math.max(1, bmp.height / this.newHeight) * blurMultiplier;
					
					var blurFilter:BlurFilter = new BlurFilter(blurXValue, blurYValue, int(BitmapFilterQuality.LOW));
					bmp.applyFilter(bmp, new Rectangle(0, 0, bmp.width, bmp.height), new Point(0, 0), blurFilter);
				}

				// Apply the resizing
				var matrix:Matrix = new Matrix();
				matrix.identity();
				matrix.createBox(this.newWidth / bmp.width, this.newHeight / bmp.height);

				resizedBmp = new BitmapData(this.newWidth, this.newHeight, true, 0x000000);
				resizedBmp.draw(bmp, matrix, null, null, null, true);
				
				bmp.dispose();
				
				if (this.encoder == ImageResizer.PNGENCODE) {
					var pngEncoder:PNGEncoder = new PNGEncoder(PNGEncoder.TYPE_SUBFILTER, 1);
					pngEncoder.addEventListener(EncodeCompleteEvent.COMPLETE, this.EncodeCompleteHandler);
					pngEncoder.addEventListener(ErrorEvent.ERROR, this.EncodeErrorHandler);
					pngEncoder.encode(resizedBmp);
				} else {
					var jpegEncoder:AsyncJPEGEncoder = new AsyncJPEGEncoder(this.quality, 0, 100);
					jpegEncoder.addEventListener(EncodeCompleteEvent.COMPLETE, this.EncodeCompleteHandler);
					jpegEncoder.encode(resizedBmp);
				}
			} catch (ex:Error) {
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Resizing: " + ex.message));
			}
		}
		
		private function EncodeErrorHandler(e:ErrorEvent):void {
			dispatchEvent(e);
		}

		private function EncodeCompleteHandler(e:EncodeCompleteEvent):void {
			dispatchEvent(new ImageResizerEvent(ImageResizerEvent.COMPLETE, e.data, this.encoder));
		}
		
	}
	
}