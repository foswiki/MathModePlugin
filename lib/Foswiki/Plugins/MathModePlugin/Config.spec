# ---+ Extensions
# ---++ MathModePlugin

# **NUMBER**
# length of the hash code. If you switch to a different 
# hash function, you will likely have to change this
$Foswiki::cfg{MathModePlugin}{HashCodeLength} = 32;

# **STRING**
# string to be prepended to any auto-generated image 
$Foswiki::cfg{MathModePlugin}{ImagePrefix} = '_MathModePlugin_';

# **SELECT png, gif**
# extension of the image type
$Foswiki::cfg{MathModePlugin}{ImageType} = 'png';

# **COMMAND**
# the command to convert a latex formula to an image
$Foswiki::cfg{MathModePlugin}{Latext2Img} = '../tools/MathModePlugin_latex2img';

# **STRING**
# latex preamble to include additional packages
# (e.g. \usepackage{mathptmx} to change the math font),
# note, that the packages =amsmath= and =color= are loaded too
# as they are obligatory 
$Foswiki::cfg{MathModePlugin}{LatexPreamble} = '\usepackage{latexsym}';

# **NUMBER**
# factor to scale images
$Foswiki::cfg{MathModePlugin}{ScaleFactor} = 1.2;

# **STRING**
# default text color 
$Foswiki::cfg{MathModePlugin}{LatexFGColor} = 'black';

# **STRING**
# default background color 
$Foswiki::cfg{MathModePlugin}{LatexBGColor} = 'white';

# **STRING**
# default font size 
$Foswiki::cfg{MathModePlugin}{LatexFontSize} = 'normalsize';

1;
