# Multi-Image Editing Guide

## Overview

ImageEdit now supports multi-image editing using the Qwen-Image-Edit-2509 model. This feature allows you to combine elements from multiple images (up to 3) to create composite edits.

## Features

- **1-3 Images**: Start with one required image, optionally add up to two more
- **Dynamic UI**: Add and remove image slots as needed
- **Image References**: Reference specific images in your prompt using "image 1", "image 2", "image 3"
- **Backward Compatible**: Single-image workflows work exactly as before

## Use Cases

### Example Prompts

1. **Person + Background**
   ```
   take the person from image 1 and put them in front of the waterfall from image 2
   ```

2. **Product Placement**
   ```
   place the product from image 1 on the table from image 2 in the style of image 3
   ```

3. **Character Compositing**
   ```
   combine the characters from image 1 and image 2 together in the scene from image 3
   ```

4. **Style Transfer with Multiple References**
   ```
   edit image 1 to have the lighting from image 2 and the colors from image 3
   ```

## How to Use

### iOS App

1. **Select First Image** (Required)
   - Tap "Select Image 1"
   - Choose an image from your photo library
   - This is your primary/base image

2. **Add More Images** (Optional)
   - Tap the "+ Add Image" button
   - Select additional images (up to 2 more)
   - Each added image gets a number (Image 2, Image 3)

3. **Remove Images**
   - Tap the trash icon next to any optional image
   - Images will be renumbered automatically

4. **Write Your Prompt**
   - Reference images by number: "image 1", "image 2", "image 3"
   - Be specific about what elements you want from each image
   - Example: "take the person from image 1 and place them in image 2's background"

5. **Generate**
   - Tap "Generate" to process
   - The AI will combine elements from all provided images

### Web Interface

1. **Select First Image** (Required)
   - Click "Select Image 1"
   - Choose an image file
   - Preview appears below the button

2. **Add More Images** (Optional)
   - Click the "+ Add Image (2/3)" button
   - A new image slot appears
   - Select additional images

3. **Remove Images**
   - Click the trash icon on any optional image slot
   - The slot is removed and remaining images are renumbered

4. **Write Your Prompt**
   - Use the same referencing system: "image 1", "image 2", "image 3"
   - The tip reminder will appear when multiple images are selected

5. **Generate**
   - Click "Generate" to process your multi-image edit

## Technical Details

### Model

- **Model**: Qwen/Qwen-Image-Edit-2509
- **Type**: QwenImageEditPlusPipeline
- **Optimal**: 1-3 images (best performance)
- **Method**: Image concatenation for multi-image processing

### API Changes

The `/edit` endpoint now accepts:
- `file` (required): First image
- `file2` (optional): Second image
- `file3` (optional): Third image

All other parameters remain the same:
- `prompt` (required): Text description
- `num_inference_steps` (default: 50)
- `true_cfg_scale` (default: 4.0)
- `seed` (optional): Random seed for reproducibility

### Backward Compatibility

Single-image requests work exactly as before. The server automatically handles both:
- Legacy single-image requests (only `file` provided)
- New multi-image requests (`file`, `file2`, and/or `file3` provided)

## Best Practices

### Prompting Tips

1. **Be Specific**: Clearly identify which elements come from which image
   - Good: "take the dog from image 1 and put it on the beach from image 2"
   - Bad: "combine these images"

2. **Reference by Number**: Always use "image 1", "image 2", "image 3"
   - The model understands these specific references

3. **Describe Relationships**: Explain how images should interact
   - "place X in front of Y"
   - "combine X with Y in the style of Z"
   - "merge X and Y together"

4. **Order Matters**: Image 1 is typically the primary/base image
   - Start with your main subject as image 1
   - Add backgrounds or reference images as 2 and 3

### Image Selection

1. **Compatible Resolutions**: Similar sizes work better
2. **Complementary Content**: Choose images that can logically combine
3. **Clear Subjects**: Images with distinct subjects are easier to reference
4. **Lighting Consistency**: Similar lighting helps create cohesive results

### Performance

- **1 Image**: Fastest, standard image editing
- **2 Images**: Good performance, most common multi-image use case
- **3 Images**: Optimal limit, more complex combinations possible

## Troubleshooting

### Common Issues

**Issue**: "The model didn't use all my images"
- **Solution**: Make sure you explicitly reference all images in your prompt

**Issue**: "Results are blurry or artifacts"
- **Solution**: Try simpler combinations, reduce the number of images, or adjust steps/guidance

**Issue**: "Images are in the wrong order"
- **Solution**: Check your prompt - the model uses the numbers you specify

**Issue**: "Can't add a third image"
- **Solution**: The limit is 3 images total. Remove one to add another.

## Examples Gallery

### Example 1: Person + Scenic Background
- **Image 1**: Portrait photo
- **Image 2**: Mountain landscape
- **Prompt**: "place the person from image 1 in front of the mountains from image 2"

### Example 2: Product Staging
- **Image 1**: Product shot
- **Image 2**: Interior room
- **Prompt**: "place the product from image 1 on the table in image 2"

### Example 3: Character Combination
- **Image 1**: Person A
- **Image 2**: Person B
- **Image 3**: Party scene
- **Prompt**: "put the people from image 1 and image 2 together at the party in image 3"

## See Also

- [API Documentation](api.md)
- [Architecture Overview](architecture.md)
- [Getting Started Guide](GETTING_STARTED.md)
