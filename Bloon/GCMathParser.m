//
//  GCMathParser.m
//
//  Created by graham on 28/08/2007.
//

#import "GCMathParser.h"


@implementation GCMathParser

static struct init s_MathFunctions[]=
{
     "sin", 	sin,
     "cos", 	cos,
     "tan", 	tan,
     "log", 	log10,
     "log2",	log2,
     "ln",		log,
     "exp", 	exp,
     "abs",		fabs,
     "sqrt", 	sqrt,
     "asin", 	asin,
     "acos", 	acos,
     "atan", 	atan,
     "sinh", 	sinh,
     "cosh", 	cosh,
     "tanh", 	tanh,
     "asinh",	asinh,
     "acosh",	acosh,
     "atanh",	atanh,
     "ceil",	ceil,
     "floor",	floor,
     "round", 	round,
     "trunc", 	trunc,
     "rint", 	rint,
     "near",	nearbyint,
     "dtor",	degtorad,
     "rtod",	radtodeg,
     0, 		0
};

+ (NSArray*) functionList
{
    static NSMutableArray* functions = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        functions = [[NSMutableArray alloc] init];
        int i = 0;
        char* fname = s_MathFunctions[0].fname;
        
        while (fname)
        {
            [functions addObject:[NSString stringWithUTF8String:fname]];
            fname = s_MathFunctions[++i].fname;
        }
    });
    
    return functions;
}

+ (double) evaluate:(NSString*) expression
{
    BOOL failed = false;
    return [[self parser] evaluate:expression failed:&failed];
}


+ (GCMathParser*)	parser
{
	return [[[GCMathParser alloc] init] autorelease];
}


- (id)				init
{
	if ((self = [super init]) != nil )
	{
		int 	i;
		symbol 	*ptr;
		
		_st = NULL;
		_expr = NULL;
		
        self->wptr = NULL;
        self->length = 0;
        self->sbuf = NULL;
        self->pFlag = false;
        
		// install mathematical functions in symbol table
	  
		for ( i = 0; s_MathFunctions[i].fname != 0; i++ )
		{
			ptr = [self initSymbol:s_MathFunctions[i].fname ofType:FUNCTION];			
			ptr->value.func = s_MathFunctions[i].fnct;
		}
		
		// also include a named constant for pi
		
		[self setSymbolValue:M_PI forKey:@"pi"];
	}
	
	return self;
}


- (void)			dealloc
{
	// free symbol table
	
	symbol	*ns, *s;
	
	s = _st;
	
	while( s )
	{
		ns = s->next;
		free( s->name );
		free( s );
		s = ns;
	}
	
	[_expr release];
	[super dealloc];
}

- (double) evaluate:(NSString*) expression failed:(BOOL*)failed
{
	[expression retain];
	[_expr release];
	_expr = expression;
	_result = 0.0;
	
	if (yyparse( self ) == 1)
    {
        *failed = true;
    }
    else
    {
        *failed = false;
    }

	// return the result...

	return _result;
}


- (NSString*)		expression
{
	return _expr;
}


- (const char*)		expressionCString
{
	return [[self expression] cStringUsingEncoding:NSUTF8StringEncoding];
}


- (void)			setSymbolValue:(double) value forKey:(NSString*) key
{
	symbol* p;
	
    char* cString = malloc(key.length + 1);
    [key getCString:cString maxLength:key.length + 1 encoding:NSUTF8StringEncoding];

	p = [self getSymbol:cString];
	
	if ( p == NULL )
    {
        p = [self initSymbol:cString ofType:VAR];
    }
	if ( p )
    {
		p->value.var = value;
    }
    free(cString);
}


- (double)			symbolValueForKey:(NSString*) key
{
    char cString[key.length + 1];
    [key getCString:cString maxLength:key.length + 1 encoding:NSUTF8StringEncoding];
	symbol*		s = [self getSymbol:cString];
	
	if ( s )
		return s->value.var;
	else
		return 0.0;
}


// private methods called internally:

- (symbol*)			getSymbol:(const char*) key
{
	symbol* s = [self getSymbolForCString:key];
    return s;
}


- (symbol*)			getSymbolForCString:(const char*) name
{
	symbol *ptr;
  	
  	for ( ptr = _st; ptr != NULL; ptr = ptr->next )
  	{
    	if ( strcmp( ptr->name, name ) == 0 )
      		return ptr;
    }
  	
	return NULL;
}


- (symbol*)			initSymbol:(const char*) name ofType:(int) type
{
	symbol*	ptr = (symbol*) malloc ( sizeof( symbol ));
  	
  	ptr->name = (char*) malloc( strlen( name ) + 1 );
  	strcpy( ptr->name, name );
  	ptr->type = type;
  	ptr->value.var = 0; // preset value to 0 even if type is a function
  	
  	ptr->next = _st;
  	_st = ptr;
 	
 	return ptr;
}


- (void)			setResult:(double) result
{
	_result = result;
}



@end


#pragma mark -

@implementation NSString (ExpressionParser)

- (double)			evaluateMath
{
	return [GCMathParser evaluate:self];
}


@end
