#!/bin/bash

# Create Feature Template Script
# Usage: ./scripts/create_feature.sh <feature_name>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <feature_name>"
    echo "Example: $0 user_profile"
    exit 1
fi

FEATURE_NAME=$1
FEATURE_NAME_CAMEL=$(echo $FEATURE_NAME | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/')
FEATURE_NAME_PASCAL=$(echo $FEATURE_NAME | sed 's/_\([a-z]\)/\U\1/g' | sed 's/^\([a-z]\)/\U\1/')

echo "Creating feature: $FEATURE_NAME"
echo "Camel case: $FEATURE_NAME_CAMEL"
echo "Pascal case: $FEATURE_NAME_PASCAL"

# Check if template exists
if [ ! -d "lib/features/template" ]; then
    echo "Error: Template not found at lib/features/template"
    exit 1
fi

# Check if target already exists
if [ -d "lib/features/$FEATURE_NAME" ]; then
    echo "Error: Feature '$FEATURE_NAME' already exists"
    exit 1
fi

# Copy template
echo "Copying template..."
cp -r lib/features/template lib/features/$FEATURE_NAME

# Function to replace text in files
replace_in_files() {
    local search=$1
    local replace=$2
    local dir=$3
    
    find "$dir" -type f -name "*.dart" -o -name "*.md" | xargs sed -i '' "s/$search/$replace/g"
}

# Replace template with feature_name
echo "Replacing template with $FEATURE_NAME..."
replace_in_files "template" "$FEATURE_NAME" "lib/features/$FEATURE_NAME"

# Replace Template with FeatureName (Pascal case)
echo "Replacing Template with $FEATURE_NAME_PASCAL..."
replace_in_files "Template" "$FEATURE_NAME_PASCAL" "lib/features/$FEATURE_NAME"

# Replace template in file paths within the files
echo "Updating import paths..."
find "lib/features/$FEATURE_NAME" -type f -name "*.dart" | xargs sed -i '' "s|template|$FEATURE_NAME|g"

# Rename files
echo "Renaming files..."
cd lib/features/$FEATURE_NAME

# Rename main files
mv template_locator.dart ${FEATURE_NAME}_locator.dart
mv template_feature_flow.dart ${FEATURE_NAME}_flow.dart
mv template_feature_router.dart ${FEATURE_NAME}_router.dart

# Rename data files
cd data
mv template_feature_constants.dart ${FEATURE_NAME}_constants.dart
cd ..

# Rename domain files
cd domain
mv template_feature_usecase.dart ${FEATURE_NAME}_usecase.dart
mv template_feature_errors.dart ${FEATURE_NAME}_errors.dart
mv template_feature_validator.dart ${FEATURE_NAME}_validator.dart
cd ..

# Rename presentation files
cd presentation/bloc
mv template_feature_cubit.dart ${FEATURE_NAME}_cubit.dart
mv template_feature_state.dart ${FEATURE_NAME}_state.dart
cd ../..

# Rename UI files
cd ui
mv template_feature_flow.dart ${FEATURE_NAME}_flow.dart
mv template_feature_router.dart ${FEATURE_NAME}_router.dart
cd screens
mv template_feature_screen.dart ${FEATURE_NAME}_screen.dart
cd ..
cd widgets
mv template_feature_widget.dart ${FEATURE_NAME}_widget.dart
cd ..
cd ..

# Update imports in all files to reflect new file names
echo "Updating imports..."
find . -type f -name "*.dart" | xargs sed -i '' "s|template_|${FEATURE_NAME}_|g"

cd ../../..

echo "Feature '$FEATURE_NAME' created successfully!"
echo ""
echo "Next steps:"
echo "1. Add your feature locator setup to lib/locator.dart"
echo "2. Add your feature router to lib/router.dart"
echo "3. Update the imports in your new feature files if needed"
echo "4. Implement your business logic"
echo "5. Test your feature"
echo ""
echo "Example integration:"
echo "In lib/locator.dart, add:"
echo "  import 'features/$FEATURE_NAME/${FEATURE_NAME}_locator.dart';"
echo "  ${FEATURE_NAME_PASCAL}Locator.setup();"
echo ""
echo "In lib/router.dart, add:"
echo "  import 'features/$FEATURE_NAME/ui/${FEATURE_NAME}_router.dart';"
echo "  ${FEATURE_NAME_PASCAL}Router.route," 