# Contributing to NetworkDriverTool

Thank you for your interest in contributing to NetworkDriverTool! We welcome contributions from the community.

## Code of Conduct

This project follows a code of conduct to ensure a welcoming environment for all contributors. By participating, you agree to:

- Be respectful and inclusive
- Focus on constructive feedback
- Accept responsibility for mistakes
- Show empathy towards other contributors
- Help create a positive community

## How to Contribute

### Reporting Issues
- Use the GitHub issue tracker to report bugs or request features
- Provide detailed information including steps to reproduce
- Include your environment details (OS, PowerShell version, etc.)

### Contributing Code

1. **Fork the Repository**
   ```bash
   git clone https://github.com/MrAmirRezaie/NetworkDriverTool.git
   cd NetworkDriverTool
   ```

2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow PowerShell best practices
   - Add tests for new functionality
   - Update documentation as needed
   - Ensure code passes all tests

4. **Run Tests**
   ```powershell
   .\NetworkDriverTool.ps1 -RunTests
   ```

5. **Commit Your Changes**
   ```bash
   git commit -m "Add feature: your feature description"
   ```

6. **Push and Create Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

### Development Guidelines

#### Code Style
- Use consistent indentation (4 spaces)
- Follow PowerShell naming conventions
- Add comments for complex logic
- Use meaningful variable names

#### Testing
- Write Pester tests for all new features
- Ensure all existing tests pass
- Test on multiple PowerShell versions if possible

#### Documentation
- Update README.md for new features
- Add inline comments for complex code
- Update parameter help for new cmdlets

### Types of Contributions

- **Bug Fixes**: Fix issues in existing code
- **Features**: Add new functionality
- **Documentation**: Improve documentation and examples
- **Tests**: Add or improve test coverage
- **Plugins**: Create new plugins for the system

### Pull Request Process

1. Ensure your PR description clearly describes the changes
2. Reference any related issues
3. Include screenshots for UI changes
4. Wait for review and address feedback
5. Once approved, your PR will be merged

### Recognition

Contributors will be recognized in the project documentation and may be added to a future contributors file.

## Development Setup

### Prerequisites
- Windows 10/11
- PowerShell 5.1+
- Git

### Setup
```powershell
# Clone repository
git clone https://github.com/MrAmirRezaie/NetworkDriverTool.git
cd NetworkDriverTool

# Install dependencies
Install-Module -Name Pester -Scope CurrentUser -Force

# Run initial tests
.\NetworkDriverTool.ps1 -RunTests
```

### Testing Your Changes
```powershell
# Run all tests
Invoke-Pester -Path .\test.ps1

# Run specific test
Invoke-Pester -Path .\test.ps1 -TestName "Specific Test Name"
```

## Questions?

If you have questions about contributing, please:
- Check existing issues and documentation
- Create a new issue for discussion
- Contact the maintainers

Thank you for contributing to NetworkDriverTool! 🚀