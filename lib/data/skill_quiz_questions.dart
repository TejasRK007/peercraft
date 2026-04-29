/// Curated MCQ question bank — 10 questions per skill, easy → hard.
library;

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

const Map<String, List<QuizQuestion>> skillQuestions = {
  'Python': [
    QuizQuestion(question: 'What is the output of print(type([]))?', options: ["<class 'list'>", "<class 'array'>", "<class 'tuple'>", "<class 'dict'>"], correctIndex: 0),
    QuizQuestion(question: 'Which keyword defines a function in Python?', options: ['func', 'def', 'define', 'function'], correctIndex: 1),
    QuizQuestion(question: 'What does len("hello") return?', options: ['4', '5', '6', 'Error'], correctIndex: 1),
    QuizQuestion(question: 'Which of these is a mutable data type?', options: ['tuple', 'string', 'list', 'int'], correctIndex: 2),
    QuizQuestion(question: 'What is a lambda function?', options: ['A named function', 'An anonymous function', 'A class method', 'A built-in'], correctIndex: 1),
    QuizQuestion(question: 'What does *args allow in a function?', options: ['Keyword arguments', 'Variable positional arguments', 'Default values', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the GIL in Python?', options: ['Global Import Lock', 'Global Interpreter Lock', 'General Instance Loader', 'None'], correctIndex: 1),
    QuizQuestion(question: 'Which method is called when an object is created?', options: ['__init__', '__new__', '__create__', '__start__'], correctIndex: 0),
    QuizQuestion(question: 'What is a generator in Python?', options: ['A class that generates random numbers', 'A function using yield to produce values lazily', 'A built-in list type', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the time complexity of dict lookup in Python?', options: ['O(n)', 'O(log n)', 'O(1) average', 'O(n²)'], correctIndex: 2),
  ],
  'Web Development': [
    QuizQuestion(question: 'What does HTML stand for?', options: ['HyperText Markup Language', 'HighText Machine Language', 'HyperTool Multi Language', 'None'], correctIndex: 0),
    QuizQuestion(question: 'Which tag creates a hyperlink?', options: ['<link>', '<a>', '<href>', '<url>'], correctIndex: 1),
    QuizQuestion(question: 'What does CSS stand for?', options: ['Computer Style Sheets', 'Cascading Style Sheets', 'Creative Style Syntax', 'None'], correctIndex: 1),
    QuizQuestion(question: 'Which HTTP method is used to send data to a server?', options: ['GET', 'PUT', 'POST', 'FETCH'], correctIndex: 2),
    QuizQuestion(question: 'What does the "box model" in CSS refer to?', options: ['3D layout', 'margin, border, padding, content', 'Grid system', 'Flexbox'], correctIndex: 1),
    QuizQuestion(question: 'What is the difference between == and === in JavaScript?', options: ['No difference', '=== checks type too', '== checks type', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is CORS?', options: ['Cross-Origin Resource Sharing', 'Client-Only Routing System', 'Custom Object Request Schema', 'None'], correctIndex: 0),
    QuizQuestion(question: 'What is the Virtual DOM?', options: ['A real DOM copy in memory', 'A lightweight in-memory representation of the real DOM', 'A browser feature', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a RESTful API?', options: ['An API using SOAP', 'An API following REST constraints over HTTP', 'A real-time API', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the difference between localStorage and sessionStorage?', options: ['No difference', 'sessionStorage clears when tab closes', 'localStorage is faster', 'Both expire in 24h'], correctIndex: 1),
  ],
  'Flutter': [
    QuizQuestion(question: 'What language does Flutter use?', options: ['Java', 'Kotlin', 'Dart', 'Swift'], correctIndex: 2),
    QuizQuestion(question: 'What is a Widget in Flutter?', options: ['A function', 'A class that describes the UI', 'A database entry', 'None'], correctIndex: 1),
    QuizQuestion(question: 'Which widget is used for scrollable content?', options: ['Column', 'Row', 'ListView', 'Stack'], correctIndex: 2),
    QuizQuestion(question: 'What is the difference between StatelessWidget and StatefulWidget?', options: ['No difference', 'StatefulWidget has mutable state', 'StatelessWidget is faster always', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is pubspec.yaml used for?', options: ['Routing', 'Declaring dependencies and assets', 'State management', 'None'], correctIndex: 1),
    QuizQuestion(question: 'Which method is called when a StatefulWidget\'s state changes?', options: ['build()', 'setState()', 'initState()', 'update()'], correctIndex: 1),
    QuizQuestion(question: 'What is the purpose of the BuildContext?', options: ['Holds widget state', 'Locates the widget in the tree', 'Manages HTTP calls', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is InheritedWidget used for?', options: ['Animations', 'Passing data down the widget tree', 'Navigation', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What does the "const" keyword do in Flutter widgets?', options: ['Makes widget mutable', 'Tells compiler widget is compile-time constant', 'Forces rebuild', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the purpose of GlobalKey in Flutter?', options: ['Unique widget identity across tree', 'Database key', 'Route key', 'None'], correctIndex: 0),
  ],
  'UI/UX Design': [
    QuizQuestion(question: 'What does UX stand for?', options: ['User Experience', 'User Exchange', 'Unique Expression', 'None'], correctIndex: 0),
    QuizQuestion(question: 'What is a wireframe?', options: ['A colored design', 'A skeletal layout of a UI', 'A prototype', 'A style guide'], correctIndex: 1),
    QuizQuestion(question: 'What is visual hierarchy?', options: ['Order of colors', 'Arrangement to guide user attention', 'Font sizes', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What does the "F-pattern" describe?', options: ['A font pattern', 'How users scan web pages', 'A grid system', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is affordance in UX design?', options: ['The cost of design', 'Visual cue that hints at an element\'s function', 'Color scheme', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a heuristic evaluation?', options: ['User testing', 'Expert review against usability principles', 'A/B testing', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is Fitt\'s Law?', options: ['The time to acquire a target depends on size and distance', 'A color theory', 'A typography rule', 'None'], correctIndex: 0),
    QuizQuestion(question: 'What is the difference between usability and accessibility?', options: ['No difference', 'Accessibility ensures use by people with disabilities', 'Usability is for developers', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a design system?', options: ['A mood board', 'A collection of reusable components and standards', 'A color palette', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the 60-30-10 rule in design?', options: ['Font sizes', 'Color proportion rule (dominant/secondary/accent)', 'Grid spacing', 'None'], correctIndex: 1),
  ],
  'Public Speaking': [
    QuizQuestion(question: 'What is the most common public speaking fear called?', options: ['Xenophobia', 'Glossophobia', 'Agoraphobia', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What does "pace" refer to in speaking?', options: ['Volume', 'Speed of delivery', 'Eye contact', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the rule of three in speeches?', options: ['Use 3 slides', 'Group ideas in threes for memorability', 'Speak for 3 minutes', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is an elevator pitch?', options: ['A formal presentation', 'A brief compelling summary delivered quickly', 'A sales pitch in an elevator', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is active listening?', options: ['Listening while doing tasks', 'Fully concentrating on the speaker', 'Nodding randomly', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the purpose of a hook in a speech?', options: ['Conclude the speech', 'Grab audience attention at the start', 'Transition between points', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is impromptu speaking?', options: ['Reading from notes', 'Speaking without prior preparation', 'Speaking with slides', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the PREP method?', options: ['Point, Reason, Example, Point', 'Prepare, Rehearse, Execute, Polish', 'None', 'Neither'], correctIndex: 0),
    QuizQuestion(question: 'What is paralanguage?', options: ['Another language', 'Non-verbal elements of speech (tone, pitch, pace)', 'Sign language', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is extemporaneous speaking?', options: ['Reading verbatim', 'Memorized speech', 'Prepared but delivered conversationally', 'Impromptu'], correctIndex: 2),
  ],
  'Guitar': [
    QuizQuestion(question: 'How many strings does a standard guitar have?', options: ['4', '5', '6', '7'], correctIndex: 2),
    QuizQuestion(question: 'What is a chord?', options: ['A single note', 'Multiple notes played together', 'A guitar pick', 'A fret'], correctIndex: 1),
    QuizQuestion(question: 'What is the nut of a guitar?', options: ['The tuning pegs', 'A small slotted strip at the headstock end', 'The body', 'The bridge'], correctIndex: 1),
    QuizQuestion(question: 'What does "capo" do?', options: ['Tunes the guitar', 'Clamps frets to raise pitch', 'Dampens strings', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a barre chord?', options: ['An open chord', 'A chord where one finger presses all strings on a fret', 'A chord without the root', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is fingerpicking?', options: ['Playing with a pick', 'Plucking strings individually with fingers', 'Strumming fast', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the pentatonic scale?', options: ['A 7-note scale', 'A 5-note scale used in blues/rock', 'A 12-tone scale', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is vibrato on guitar?', options: ['A fast scale run', 'Oscillating pitch by bending/releasing a note', 'A chord technique', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is fingerstyle guitar?', options: ['Using a pick', 'Playing melody, bass and harmony simultaneously with fingers', 'Strumming chords', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a tritone substitution?', options: ['A basic chord swap', 'Replacing a dominant chord with one a tritone away', 'A strumming pattern', 'None'], correctIndex: 1),
  ],
  'Video Editing': [
    QuizQuestion(question: 'What is a cut in video editing?', options: ['Deleting footage', 'An instant transition between clips', 'A fade effect', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What does FPS stand for?', options: ['File Processing Speed', 'Frames Per Second', 'Format Per Scene', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a B-roll?', options: ['The main footage', 'Supplementary footage to cover narration', 'An error in editing', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is color grading?', options: ['Adding text overlays', 'Adjusting color to set tone/mood', 'Cropping video', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a keyframe?', options: ['A frame with a key person', 'A reference frame defining start/end of an animation', 'The first frame', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the J-cut technique?', options: ['Cutting on a J shape', 'Audio from next clip starts before video transitions', 'A jump cut', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is dynamic range in video?', options: ['Camera movement speed', 'Ratio between lightest and darkest values', 'Frame rate range', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is LUT in color grading?', options: ['Look Up Table — maps one color space to another', 'A filter effect', 'A text style', 'None'], correctIndex: 0),
    QuizQuestion(question: 'What is the 180-degree rule?', options: ['Camera rotation limit', 'Camera should not cross the axis between subjects', 'A editing transition rule', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is temporal aliasing in video?', options: ['Audio distortion', 'Visual stuttering caused by frame rate mismatch with motion', 'Color bleeding', 'None'], correctIndex: 1),
  ],
  'Data Science': [
    QuizQuestion(question: 'What does CSV stand for?', options: ['Comma Separated Values', 'Computer Stored Variables', 'Categorized Sample Values', 'None'], correctIndex: 0),
    QuizQuestion(question: 'What is a DataFrame in pandas?', options: ['A single column', '2D tabular data structure', 'A chart', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the mean of [2, 4, 6, 8]?', options: ['4', '5', '6', '3'], correctIndex: 1),
    QuizQuestion(question: 'What is overfitting in ML?', options: ['Model performs well on both', 'Model memorizes training data, fails on new data', 'Model underfits', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is a confusion matrix used for?', options: ['Data cleaning', 'Evaluating classification model performance', 'Feature selection', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is regularization in ML?', options: ['Removing outliers', 'Technique to prevent overfitting by penalizing complexity', 'Scaling data', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the difference between L1 and L2 regularization?', options: ['No difference', 'L1 produces sparse models; L2 shrinks weights uniformly', 'L2 is faster', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the curse of dimensionality?', options: ['Too much data', 'Exponential growth of space with more features', 'Slow training', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is gradient boosting?', options: ['A neural network technique', 'Ensemble method building models sequentially on residuals', 'A data cleaning step', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the bias-variance tradeoff?', options: ['Speed vs accuracy', 'Balance between underfitting (bias) and overfitting (variance)', 'Data vs model size', 'None'], correctIndex: 1),
  ],
  'Photography': [
    QuizQuestion(question: 'What does ISO control in photography?', options: ['Color balance', 'Camera sensor sensitivity to light', 'Lens zoom', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is aperture measured in?', options: ['Seconds', 'f-stops', 'ISO', 'mm'], correctIndex: 1),
    QuizQuestion(question: 'What is the rule of thirds?', options: ['Using 3 colors', 'Dividing frame into 9 parts to place subjects at intersections', 'Taking 3 shots', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is shutter speed?', options: ['Lens speed', 'Duration sensor is exposed to light', 'AF speed', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is depth of field?', options: ['Photo file depth', 'Range of distance that appears sharp in an image', 'Zoom level', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is white balance?', options: ['Exposure setting', 'Adjustment to make whites appear neutral under different lights', 'ISO setting', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is bokeh?', options: ['A blur type', 'The aesthetic quality of out-of-focus blur', 'A lens brand', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is RAW format?', options: ['Compressed image', 'Unprocessed image data from sensor', 'A filter', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is the exposure triangle?', options: ['Three light sources', 'ISO, aperture, shutter speed relationship', 'Three-point lighting', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is focus peaking?', options: ['Auto focus mode', 'Highlight of in-focus edges to aid manual focus', 'A lens type', 'None'], correctIndex: 1),
  ],
  'Dance': [
    QuizQuestion(question: 'What is the basic unit of music that dancers count to?', options: ['Measure/bar', 'Tempo', 'Rhythm', 'Beat'], correctIndex: 3),
    QuizQuestion(question: 'What does "downbeat" mean?', options: ['A slow song', 'The first and strongest beat in a measure', 'A dance move', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is choreography?', options: ['Music composition', 'Sequencing and designing dance movements', 'Stage lighting', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is spotting in dance turns?', options: ['Finding a dance partner', 'Fixing gaze on a point to avoid dizziness while spinning', 'A jump technique', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is isolation in dance?', options: ['Dancing alone', 'Moving one body part independently of others', 'A freeze pose', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is syncopation in dance?', options: ['Moving on off-beats or between beats', 'Dancing in sync with others', 'A jump sequence', 'None'], correctIndex: 0),
    QuizQuestion(question: 'What is musicality in dance?', options: ['Playing music while dancing', 'Ability to express music\'s dynamics through movement', 'A dance style', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is contrapposto in dance/movement?', options: ['A jump', 'Counter-positioning of shoulders and hips', 'A partner hold', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is Laban Movement Analysis?', options: ['A dance style', 'A framework to describe and interpret human movement', 'A music theory', 'None'], correctIndex: 1),
    QuizQuestion(question: 'What is floor work in contemporary dance?', options: ['Stage maintenance', 'Movement sequences performed on the floor', 'Ballet barre work', 'None'], correctIndex: 1),
  ],
};

/// Returns questions for a skill, falling back to generic questions if not found.
List<QuizQuestion> getQuestionsForSkill(String skill) {
  // Exact match
  if (skillQuestions.containsKey(skill)) return skillQuestions[skill]!;
  // Case-insensitive match
  final key = skillQuestions.keys.firstWhere(
    (k) => k.toLowerCase() == skill.toLowerCase(),
    orElse: () => '',
  );
  if (key.isNotEmpty) return skillQuestions[key]!;
  // Generic fallback
  return _genericQuestions(skill);
}

List<QuizQuestion> _genericQuestions(String skill) => [
  QuizQuestion(question: 'Which term best describes $skill at a beginner level?', options: ['Expert mastery', 'Basic familiarity', 'No knowledge', 'Advanced application'], correctIndex: 1),
  QuizQuestion(question: 'What is the first step to learning $skill?', options: ['Jump to advanced topics', 'Understand fundamentals', 'Skip theory', 'None'], correctIndex: 1),
  QuizQuestion(question: 'Which habit helps most when practicing $skill?', options: ['Random practice', 'Consistent daily practice', 'Only reading', 'Watching others'], correctIndex: 1),
  QuizQuestion(question: 'How do you measure progress in $skill?', options: ['Time spent', 'Skill milestones and feedback', 'Money spent', 'None'], correctIndex: 1),
  QuizQuestion(question: 'What makes someone intermediate in $skill?', options: ['Knowing basics only', 'Can apply concepts independently', 'Expert level', 'Never practiced'], correctIndex: 1),
  QuizQuestion(question: 'What is a common mistake beginners make in $skill?', options: ['Practicing too much', 'Skipping fundamentals', 'Seeking feedback', 'None'], correctIndex: 1),
  QuizQuestion(question: 'How does teaching $skill to others help you?', options: ['It doesn\'t', 'Deepens your own understanding', 'Wastes time', 'None'], correctIndex: 1),
  QuizQuestion(question: 'What is a good resource for learning $skill?', options: ['Unverified sources only', 'Structured courses and practice', 'Social media only', 'None'], correctIndex: 1),
  QuizQuestion(question: 'What distinguishes an advanced practitioner of $skill?', options: ['Years of passive exposure', 'Deep expertise and ability to innovate', 'Basic knowledge', 'None'], correctIndex: 1),
  QuizQuestion(question: 'What is the best approach to mastering $skill?', options: ['Cramming', 'Deliberate practice with feedback', 'Reading only', 'None'], correctIndex: 1),
];
