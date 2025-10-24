const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

exports.handler = async (event) => {
    console.log('Claude Analysis Function triggered via AWS Bedrock');

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    };

    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    try {
        // Parse request body
        const body = JSON.parse(event.body || '{}');
        const { prompt, model = 'claude-3-5-sonnet-v2', maxTokens = 4096, temperature = 0.1 } = body;

        if (!prompt) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'Prompt is required',
                    message: 'Please provide prompt content for Claude analysis'
                })
            };
        }

        try {
            // Call Claude via AWS Bedrock
            const claudeResponse = await callClaudeBedrock({
                model,
                prompt,
                maxTokens,
                temperature
            });

            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({
                    success: true,
                    analysis: claudeResponse.content,
                    usage: claudeResponse.usage,
                    model: claudeResponse.model
                })
            };

        } catch (bedrockError) {
            console.error('AWS Bedrock Error:', bedrockError);

            // Fallback to mock analysis if Bedrock fails
            console.log('Falling back to mock analysis due to Bedrock error');
            return handleMockAnalysis(prompt);
        }

    } catch (error) {
        console.error('Error in Claude Analysis Function:', error);

        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: 'Failed to process document analysis',
                details: process.env.NODE_ENV === 'development' ? error.message : undefined
            })
        };
    }
};

async function callClaudeBedrock({ model, prompt, maxTokens, temperature }) {
    // Map model names to Bedrock model IDs (using models with on-demand throughput support)
    const modelMap = {
        'claude-3-5-sonnet-v2': 'anthropic.claude-3-5-sonnet-20240620-v1:0', // Using v1 which supports on-demand
        'claude-3-5-sonnet': 'anthropic.claude-3-5-sonnet-20240620-v1:0',
        'claude-3-sonnet': 'anthropic.claude-3-sonnet-20240229-v1:0',
        'claude-3-haiku': 'anthropic.claude-3-haiku-20240307-v1:0',
        'claude-3-opus': 'anthropic.claude-3-opus-20240229-v1:0'
    };

    const bedrockModelId = modelMap[model] || modelMap['claude-3-5-sonnet'];

    // Initialize Bedrock client
    const bedrockClient = new BedrockRuntimeClient({
        region: process.env.AWS_REGION || 'us-east-1'
    });

    // Prepare the request body for Claude via Bedrock
    const requestBody = {
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: maxTokens,
        temperature: temperature,
        messages: [
            {
                role: "user",
                content: prompt
            }
        ]
    };

    try {
        console.log(`Calling Claude via Bedrock with model: ${bedrockModelId}`);

        const command = new InvokeModelCommand({
            modelId: bedrockModelId,
            contentType: 'application/json',
            accept: 'application/json',
            body: JSON.stringify(requestBody)
        });

        const response = await bedrockClient.send(command);

        // Parse the response
        const responseBody = JSON.parse(new TextDecoder().decode(response.body));

        console.log('Bedrock response received successfully');

        return {
            content: responseBody.content[0].text,
            usage: responseBody.usage || {
                input_tokens: 0,
                output_tokens: 0,
                total_tokens: 0
            },
            model: bedrockModelId
        };

    } catch (error) {
        console.error('Error calling Claude via Bedrock:', error);
        throw error;
    }
}

function handleMockAnalysis(prompt) {
    console.log('Generating mock analysis for prompt:', prompt.substring(0, 100) + '...');

    // Generate contextual mock analysis based on prompt content
    const isEscrowAnalysis = prompt.toLowerCase().includes('escrow');
    const isMortgageStatement = prompt.toLowerCase().includes('mortgage statement') || prompt.toLowerCase().includes('payment');

    let mockFindings;

    if (isEscrowAnalysis) {
        mockFindings = [
            {
                "issueType": "escrowError",
                "severity": "medium",
                "title": "Mock: Escrow Calculation Review",
                "description": "Mock analysis suggests reviewing escrow account calculations and cushion amounts.",
                "detailedExplanation": "This is a simulated finding. Configure Claude API key for detailed escrow analysis including RESPA compliance checks, cushion calculations, and disbursement timing verification.",
                "suggestedAction": "Configure Claude API key in backend environment variables for comprehensive analysis.",
                "affectedAmount": null,
                "confidence": 0.6,
                "evidenceText": "Mock analysis - requires real API configuration",
                "reasoning": "Demonstration mode active"
            }
        ];
    } else if (isMortgageStatement) {
        mockFindings = [
            {
                "issueType": "latePaymentError",
                "severity": "medium",
                "title": "Mock: Payment Allocation Check",
                "description": "Mock analysis detected potential payment allocation patterns that warrant review.",
                "detailedExplanation": "This is a simulated finding for demonstration. Real Claude AI analysis would provide detailed payment allocation verification, interest calculations, and RESPA compliance checking.",
                "suggestedAction": "Configure Claude API key for comprehensive mortgage statement analysis.",
                "affectedAmount": 75.50,
                "confidence": 0.65,
                "evidenceText": "Mock evidence for demonstration purposes",
                "reasoning": "Demo analysis - real API needed for accurate results"
            }
        ];
    } else {
        mockFindings = [
            {
                "issueType": "other",
                "severity": "low",
                "title": "Mock: Document Review",
                "description": "Mock analysis suggests manual document review.",
                "detailedExplanation": "This is a placeholder finding. Configure Claude API key for AI-powered analysis that can identify complex patterns, RESPA violations, and provide detailed financial calculations.",
                "suggestedAction": "Set up Claude API key in backend environment for full analysis capabilities.",
                "affectedAmount": null,
                "confidence": 0.5,
                "evidenceText": "Mock analysis placeholder",
                "reasoning": "Demonstration mode - requires API configuration"
            }
        ];
    }

    const mockResponse = {
        "findings": mockFindings,
        "overallConfidence": 0.6,
        "summary": "Mock analysis completed due to Bedrock connection failure. This is a demonstration of the analysis format. Check AWS Bedrock permissions and model availability for real AI-powered mortgage servicing error detection."
    };

    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        },
        body: JSON.stringify({
            success: true,
            analysis: JSON.stringify(mockResponse),
            usage: {
                input_tokens: 0,
                output_tokens: 0,
                total_tokens: 0
            },
            model: "mock-analysis",
            note: "Mock analysis - Bedrock connection failed, check IAM permissions and model availability"
        })
    };
}