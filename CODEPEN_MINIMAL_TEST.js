// ============================================
// MINIMAL TEST - Use this to verify your URL works
// ============================================
// 1. Upload FINAL_STORY.json to GitHub
// 2. Get the raw URL
// 3. Paste it below
// 4. Run this in CodePen JS panel
// ============================================

const TEST_URL = 'YOUR_GITHUB_RAW_URL_HERE';
// Example: 'https://raw.githubusercontent.com/username/repo/main/FINAL_STORY.json'

console.log('🧪 Testing story database URL...');
console.log('📍 URL:', TEST_URL);

fetch(TEST_URL)
  .then(response => {
    console.log('📡 Response status:', response.status, response.statusText);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    return response.text();
  })
  .then(text => {
    console.log('📥 Downloaded:', text.length, 'characters');
    console.log('🔍 First 100 chars:', text.substring(0, 100));
    
    // Try to execute it
    eval(text);
    
    // Check if STORY_DATABASE exists
    if (typeof STORY_DATABASE !== 'undefined') {
      const sceneCount = Object.keys(STORY_DATABASE).length;
      console.log('✅ SUCCESS! STORY_DATABASE loaded with', sceneCount, 'scenes');
      console.log('🎬 First scene:', Object.keys(STORY_DATABASE)[0]);
      console.log('✅ Has intro scene:', STORY_DATABASE.intro ? 'YES' : 'NO');
      
      // Show intro text preview
      if (STORY_DATABASE.intro && STORY_DATABASE.intro.text) {
        console.log('📖 Intro preview:', STORY_DATABASE.intro.text.substring(0, 100) + '...');
      }
      
      console.log('\n✅ EVERYTHING WORKS! You can now use this URL in your game.');
    } else {
      console.error('❌ STORY_DATABASE not defined after loading');
    }
  })
  .catch(error => {
    console.error('❌ FAILED:', error.message);
    console.error('');
    console.error('Common issues:');
    console.error('  1. Wrong URL - make sure it\'s the "raw" GitHub URL');
    console.error('  2. File not public - check repository visibility');
    console.error('  3. CORS issue - GitHub raw should work, but some hosts block it');
    console.error('  4. Network error - check your internet connection');
  });