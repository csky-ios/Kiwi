//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWAfterAllNode.h"
#import "KWAfterEachNode.h"
#import "KWBeforeAllNode.h"
#import "KWBeforeEachNode.h"
#import "KWLetNode.h"
#import "KWCallSite.h"
#import "KWContextNode.h"
#import "KWExampleNodeVisitor.h"
#import "KWExample.h"
#import "KWFailure.h"
#import "KWRegisterMatchersNode.h"
#import "KWSymbolicator.h"

@interface KWContextNode()

@property (nonatomic, assign) NSUInteger performedExampleCount;

@end

@implementation KWContextNode

#pragma mark - Initializing

- (id)initWithCallSite:(KWCallSite *)aCallSite parentContext:(KWContextNode *)node description:(NSString *)aDescription {
    self = [super init];
    if (self) {
        _parentContext = node;
        _callSite = aCallSite;
        _description = [aDescription copy];
        _nodes = [[NSMutableArray alloc] init];
        _letNodes = [[NSMutableArray alloc] init];
        _performedExampleCount = 0;
    }

    return self;
}

+ (id)contextNodeWithCallSite:(KWCallSite *)aCallSite parentContext:(KWContextNode *)contextNode description:(NSString *)aDescription {
    return [[self alloc] initWithCallSite:aCallSite parentContext:contextNode description:aDescription];
}

- (void)addContextNode:(KWContextNode *)aNode {
    [(NSMutableArray *)self.nodes addObject:aNode];
}

- (void)setRegisterMatchersNode:(KWRegisterMatchersNode *)aNode {
    if (self.registerMatchersNode != nil)
        [NSException raise:@"KWContextNodeException" format:@"a register matchers node already exists"];

    _registerMatchersNode = aNode;
}

- (void)setBeforeEachNode:(KWBeforeEachNode *)aNode {
    if (self.beforeEachNode != nil)
        [NSException raise:@"KWContextNodeException" format:@"a before each node already exists"];

    _beforeEachNode = aNode;
}

- (void)setAfterEachNode:(KWAfterEachNode *)aNode {
    if (self.afterEachNode != nil)
        [NSException raise:@"KWContextNodeException" format:@"an after each node already exists"];

    _afterEachNode = aNode;
}

- (void)addLetNode:(KWLetNode *)aNode
{
    [(NSMutableArray *)self.letNodes addObject:aNode];
}

- (KWLetNode *)letNodeTree
{
    KWLetNode *tree = [self.parentContext letNodeTree];
    for (KWLetNode *letNode in self.letNodes) {
        if (!tree) {
            tree = letNode;
        }
        else {
            [tree addLetNode:letNode];
        }
    }
    return tree;
}

- (void)addItNode:(KWItNode *)aNode {
    [(NSMutableArray *)self.nodes addObject:aNode];
}

- (void)addPendingNode:(KWPendingNode *)aNode {
    [(NSMutableArray *)self.nodes addObject:aNode];
}

- (void)performExample:(KWExample *)example withBlock:(void (^)(void))exampleBlock
{
    void (^innerExampleBlock)(void) = [exampleBlock copy];
    
    void (^outerExampleBlock)(void) = ^{
        @try {
            [self.registerMatchersNode acceptExampleNodeVisitor:example];
            
            if (self.performedExampleCount == 0) {
                [self.beforeAllNode acceptExampleNodeVisitor:example];
            }

            KWLetNode *letNodeTree = [self letNodeTree];
            [letNodeTree acceptExampleNodeVisitor:example];

            [self.beforeEachNode acceptExampleNodeVisitor:example];

            innerExampleBlock();

            [self.afterEachNode acceptExampleNodeVisitor:example];

            if ([example isLastInContext:self]) {
                [self.afterAllNode acceptExampleNodeVisitor:example];
                [letNodeTree unlink];
            }

        } @catch (NSException *exception) {
            KWFailure *failure = [KWFailure failureWithCallSite:self.callSite format:@"%@ \"%@\" raised", [exception name], [exception reason]];
            [example reportFailure:failure];
        }
        
        self.performedExampleCount++;
    };
    if (self.parentContext == nil) {
        outerExampleBlock();
    }
    else {
        [self.parentContext performExample:example withBlock:outerExampleBlock];
    }
}

#pragma mark - Accepting Visitors

- (void)acceptExampleNodeVisitor:(id<KWExampleNodeVisitor>)aVisitor {
    [aVisitor visitContextNode:self];
}

@synthesize description=_description;
@end
