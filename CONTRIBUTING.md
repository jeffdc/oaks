# Contributing to Quercus Database

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- A clear, descriptive title
- Steps to reproduce the problem
- Expected vs. actual behavior
- Your environment (OS, Python version)
- Relevant logs or error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please open an issue with:
- A clear description of the enhancement
- Why this would be useful
- Any implementation ideas you have

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes**:
   - Follow existing code style
   - Add comments for complex logic
   - Update documentation if needed
3. **Test your changes**:
   - Ensure the scraper still works
   - Test the query interface in multiple browsers
4. **Commit your changes**:
   - Use clear, descriptive commit messages
   - Reference any related issues
5. **Submit a pull request**

## Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/quercus-database.git
cd quercus-database

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the scraper
python scraper.py
```

## Code Style

- Follow PEP 8 guidelines
- Use meaningful variable names
- Add docstrings to functions
- Keep functions focused and modular

## Testing

Before submitting a PR:
- Test the scraper with `--restart` flag
- Verify resume functionality works
- Check the query interface loads and searches correctly
- Ensure no errors in browser console

## Data Quality

When improving the scraper:
- Preserve all existing data fields
- Handle missing data gracefully (use `None` or empty lists)
- Maintain backwards compatibility with the JSON schema
- Document any schema changes in the PR

## Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues: "Fix #123: Add hybrid parent validation"

## Questions?

Feel free to open an issue for any questions about contributing!