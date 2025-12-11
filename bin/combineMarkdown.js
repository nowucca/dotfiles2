#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Combines all markdown files in a directory into a single file
 * while preserving directory structure context
 */

// Parse command line arguments
const args = process.argv.slice(2);
if (args.length < 1) {
  console.error('Usage: node combineMarkdown.js <inputDirectory> [outputFile] [--exclude=pattern1,pattern2,...] [--title="Custom Title"]');
  console.error('Example: node combineMarkdown.js docs output.md --exclude=draft-*,temp/* --title="Project Documentation"');
  process.exit(1);
}

const inputDir = args[0];
let outputFile = 'combined_markdown.md';
let excludePatterns = [];
let documentTitle = 'Combined Markdown Files';

// Process remaining arguments
for (let i = 1; i < args.length; i++) {
  const arg = args[i];
  if (arg.startsWith('--exclude=')) {
    // Extract exclude patterns
    const patterns = arg.substring('--exclude='.length).split(',');
    excludePatterns = patterns.map(p => new RegExp(p.replace(/\*/g, '.*')));
  } else if (arg.startsWith('--title=')) {
    // Extract custom title
    documentTitle = arg.substring('--title='.length);
    // Remove surrounding quotes if present
    if ((documentTitle.startsWith('"') && documentTitle.endsWith('"')) || 
        (documentTitle.startsWith("'") && documentTitle.endsWith("'"))) {
      documentTitle = documentTitle.substring(1, documentTitle.length - 1);
    }
  } else if (!arg.startsWith('--')) {
    // Assume it's the output file
    outputFile = arg;
  }
}

// Validate input directory
if (!fs.existsSync(inputDir)) {
  console.error(`Error: Directory "${inputDir}" does not exist.`);
  process.exit(1);
}

// Function to check if a file should be excluded based on patterns
function shouldExclude(filePath, patterns) {
  if (patterns.length === 0) return false;
  
  return patterns.some(pattern => pattern.test(filePath));
}

// Function to find all markdown files in a directory and its subdirectories
function findMarkdownFiles(dir, fileList = [], baseDir = dir) {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const relativePath = path.relative(baseDir, filePath);
    
    // Skip if the file or directory matches an exclude pattern
    if (shouldExclude(relativePath, excludePatterns)) {
      console.log(`Skipping excluded path: ${relativePath}`);
      return;
    }
    
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      // Recursively search subdirectories
      findMarkdownFiles(filePath, fileList, baseDir);
    } else if (file.toLowerCase().endsWith('.md')) {
      // Add markdown files to the list with their relative path
      fileList.push({
        absolutePath: filePath,
        relativePath: relativePath
      });
    }
  });
  
  return fileList;
}

// Function to read file content
function readFileContent(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch (error) {
    console.error(`Error reading file ${filePath}: ${error.message}`);
    return `[Error reading file: ${error.message}]`;
  }
}

// Function to organize files by directory structure
function organizeByDirectory(files) {
  const structure = {};
  
  files.forEach(file => {
    const dirPath = path.dirname(file.relativePath);
    if (!structure[dirPath]) {
      structure[dirPath] = [];
    }
    structure[dirPath].push(file);
  });
  
  return structure;
}

// Function to generate output content with headers and table of contents
function generateOutput(structure) {
  let output = `# ${documentTitle}\n\nGenerated on ${new Date().toLocaleString()}\n\n`;
  let tableOfContents = `## Table of Contents\n\n`;
  let contentSection = '';
  
  // Sort directories to maintain consistent order
  const directories = Object.keys(structure).sort();
  
  // Generate table of contents
  directories.forEach(dir => {
    const dirName = dir === '.' ? 'Root Directory' : `Directory: ${dir}`;
    const dirLink = dir === '.' ? 'root-directory' : `directory-${dir.replace(/\//g, '-')}`;
    tableOfContents += `- [${dirName}](#${dirLink})\n`;
    
    // Add file links under each directory
    const files = structure[dir].sort((a, b) => 
      a.relativePath.localeCompare(b.relativePath)
    );
    
    files.forEach(file => {
      const fileName = path.basename(file.relativePath);
      const fileLink = `file-${file.relativePath.replace(/\//g, '-').replace(/\./g, '-')}`;
      tableOfContents += `  - [${fileName}](#${fileLink})\n`;
    });
  });
  
  tableOfContents += `\n---\n\n`;
  
  // Generate content sections
  directories.forEach(dir => {
    // Add directory header
    if (dir === '.') {
      contentSection += `<a id="root-directory"></a>\n## Root Directory\n\n`;
    } else {
      contentSection += `<a id="directory-${dir.replace(/\//g, '-')}"></a>\n## Directory: ${dir}\n\n`;
    }
    
    // Sort files within directory
    const files = structure[dir].sort((a, b) => 
      a.relativePath.localeCompare(b.relativePath)
    );
    
    // Add each file's content with a header
    files.forEach(file => {
      const fileName = path.basename(file.relativePath);
      const content = readFileContent(file.absolutePath);
      const fileLink = `file-${file.relativePath.replace(/\//g, '-').replace(/\./g, '-')}`;
      
      contentSection += `<a id="${fileLink}"></a>\n### File: ${file.relativePath}\n\n`;
      contentSection += `${content}\n\n`;
      contentSection += `---\n\n`; // Separator between files
    });
  });
  
  return output + tableOfContents + contentSection;
}

// Main execution
try {
  console.log(`Scanning directory: ${inputDir}`);
  const markdownFiles = findMarkdownFiles(inputDir);
  
  if (markdownFiles.length === 0) {
    console.log('No markdown files found.');
    process.exit(0);
  }
  
  console.log(`Found ${markdownFiles.length} markdown files.`);
  
  const fileStructure = organizeByDirectory(markdownFiles);
  const outputContent = generateOutput(fileStructure);
  
  // Write to output file
  fs.writeFileSync(outputFile, outputContent);
  console.log(`Successfully combined markdown files into: ${outputFile}`);
  
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exit(1);
}