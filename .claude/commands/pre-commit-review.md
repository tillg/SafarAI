# Pre-Commit Review

Before committing changes to git, perform a comprehensive review of the codebase:

## 1. Check Directory Structure & File Organization

Review the Swift file organization:
- Are files in the correct directories (Models/, Views/, Utils/)?
- Are new files properly organized?
- Is the directory structure consistent?

## 2. Identify Unused Code

Search for:
- Unused imports
- Unused variables or functions
- Dead code that's commented out
- Obsolete files that should be deleted

## 3. Architecture

Check that
- Architecture is coherent
- Repeated logic that could be extracted into shared functions
- If it can’t be tested in 10ms without UI or network, it’s badly designed.
  

## 4. Find Duplicate Code

Look for:
- Similar view code that could be componentized
- Duplicate constants or configurations

## 5. Code Quality Issues

Check for:
- TODO/FIXME comments that need addressing
- Debug print statements that should be removed
- Hardcoded values that should be constants
- Force unwraps (!) that could be safer
- Error handling that could be improved

## 6. SwiftUI Best Practices

Verify:
- View components are properly extracted and reusable
- State management is appropriate (@State, @Binding, @Query)
- Preview providers exist for new views
- Proper use of SwiftData relationships
- Check against Specs/BEST_PRACTICE_*.md
- View have reasonable #Preview s
- Make sure to check all the aspects covered in ../BEST_PRACTICES/GUIDE_FROM_PAUL_HUDSON.md

## 7. Documentation

Ensure:
- New public functions have comments
- Complex logic is explained
- File headers are present
- README or specs are updated if needed

## 8. Complexity

Ensure we don't have over complex code. 

* Are there areas / funcztionality that we could implement much easier, with simpler code?
* Are there code parts that can be shrunk?
* Especially in formatting the output / modifiers: Do we need them all? Are they maybe modifying one another and could be simplified?

## Output Format

Provide:
1. Summary of issues found (if any)
2. Specific file locations with line numbers
3. Recommendations for improvements
4. Priority level (High/Medium/Low) for each issue

Don't modify any files, just produce a report.
If everything looks good, simply state: "✅ Code review passed - ready to commit"
