shared_examples_for 'inputtable' do |options = {}|

    let( :opts ) do
        { single_input: false }.merge( options )
    end

    let(:inputs) do
        if opts[:single_input]
            { 'input1' => 'value1' }
        else
            {
                'input1' => 'value1',
                'input2' => 'value2'
            }
        end
    end

    let(:sym_key_inputs) { inputs.my_symbolize_keys }

    let(:keys) do
        subject.inputs.keys
    end

    let(:sym_keys) do
        keys.map(&:to_sym)
    end

    let(:non_existent_keys) do
        inputs.keys.map { |k| "#{k}1" }
    end

    let(:non_existent_sym_keys) do
        non_existent_keys.map(&:to_sym)
    end

    subject do
        begin
            inputtable
        rescue
            described_class.new( url: url, inputs: inputs )
        end
    end

    it "supports #{Arachni::RPC::Serializer}" do
        subject.should == Arachni::RPC::Serializer.deep_clone( subject )
    end

    describe '#to_rpc_data' do
        let(:data) { subject.to_rpc_data }

        %w(inputs default_inputs).each do |attribute|
            it "includes '#{attribute}'" do
                data[attribute].should == subject.send( attribute )
            end
        end
    end

    describe '.from_rpc_data' do
        let(:restored) { subject.class.from_rpc_data data }
        let(:data) { Arachni::RPC::Serializer.rpc_data( subject ) }

        %w(inputs default_inputs).each do |attribute|
            it "restores '#{attribute}'" do
                restored.send( attribute ).should == subject.send( attribute )
            end
        end
    end

    describe '#reset' do
        it 'returns the element to its original state' do
            orig = subject.dup

            k, v = orig.inputs.keys.first, 'value'

            subject.update( k => v )
            subject.affected_input_name = k
            subject.affected_input_value = v
            subject.seed = v

            subject.inputs.should_not == orig.inputs
            subject.affected_input_name.should_not == orig.affected_input_name
            subject.affected_input_value.should_not == orig.affected_input_value
            subject.seed.should_not == orig.seed

            subject.reset

            subject.inputs.should == orig.inputs

            subject.affected_input_name.should == orig.affected_input_name
            subject.affected_input_name.should be_nil

            subject.affected_input_value.should == orig.affected_input_value
            subject.affected_input_value.should be_nil

            subject.seed.should == orig.seed
            subject.seed.should be_nil
        end
    end

    describe '#has_inputs?' do
        context 'when the given inputs are' do
            context 'variable arguments' do
                context 'when it has the given inputs' do
                    it 'returns true' do
                        keys.each do |k|
                            subject.has_inputs?( k.to_s.to_sym ).should be_true
                            subject.has_inputs?( k.to_s ).should be_true
                        end

                        subject.has_inputs?( *sym_keys ).should be_true
                        subject.has_inputs?( *keys ).should be_true
                    end
                end
                context 'when it does not have the given inputs' do
                    it 'returns false' do
                        subject.has_inputs?( *non_existent_sym_keys ).should be_false
                        subject.has_inputs?( *non_existent_keys ).should be_false

                        subject.has_inputs?( non_existent_keys.first ).should be_false
                    end
                end
            end

            context Array do
                context 'when it has the given inputs' do
                    it 'returns true' do
                        subject.has_inputs?( sym_keys ).should be_true
                        subject.has_inputs?( keys ).should be_true
                    end
                end
                context 'when it does not have the given inputs' do
                    it 'returns false' do
                        subject.has_inputs?( non_existent_sym_keys ).should be_false
                        subject.has_inputs?( non_existent_keys ).should be_false
                    end
                end
            end

            context Hash do
                context 'when it has the given inputs (names and values)' do
                    it 'returns true' do
                        subject.has_inputs?( subject.inputs ).should be_true
                        subject.has_inputs?( subject.inputs.my_symbolize_keys ).should be_true
                    end
                end
                context 'when it does not have the given inputs' do
                    it 'returns false' do
                        subject.has_inputs?(
                            inputs.keys.first => "#{inputs.values.first} 1"
                        ).should be_false
                    end
                end
            end
        end
    end

    describe '#inputs' do
        it 'is frozen' do
            subject.inputs.should be_frozen
        end
    end

    describe '#inputtable_id' do
        it 'takes into account input names' do
            e = subject.dup
            e.stub(:inputs) { { 1 => 2 } }

            c = subject.dup
            c.stub(:inputs) { { 1 => 2 } }

            e.inputtable_id.should == c.inputtable_id

            e = subject.dup
            e.stub(:inputs) { { 1 => 2 } }

            c = subject.dup
            c.stub(:inputs) { { 2 => 2 } }

            e.inputtable_id.should_not == c.inputtable_id
        end

        it 'takes into account input values' do
            e = subject.dup
            e.stub(:inputs) { { 1 => 2 } }

            c = subject.dup
            c.stub(:inputs) { { 1 => 2 } }

            e.inputtable_id.should == c.inputtable_id

            e = subject.dup
            e.stub(:inputs) { { 1 => 1 } }

            c = subject.dup
            c.stub(:inputs) { { 1 => 2 } }

            e.inputtable_id.should_not == c.inputtable_id
        end

        it 'ignores input order' do
            e = subject.dup
            e.stub(:inputs) { { 1 => 2, 3 => 4 } }

            c = subject.dup
            c.stub(:inputs) { { 3 => 4, 1 => 2 } }

            e.inputtable_id.should == c.inputtable_id
        end
    end

    describe '#inputs=' do
        it 'assigns a hash of auditable inputs' do
            a = subject.dup
            a.inputs = { 'input1' => 'val1' }
            a.inputs.should == { 'input1' => 'val1' }
        end

        it 'converts all inputs to strings' do
            subject.inputs = { input1: nil }
            subject.inputs.should == { 'input1' => '' }
        end

        context 'when the input name' do
            context 'contains invalid data' do
                it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name}" do
                    subject.stub(:valid_input_data?) { |data| data != 'input1' }

                    expect do
                        subject.inputs = { 'input1' => 'blah' }
                    end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name
                end
            end

            context 'is invalid' do
                it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name}" do
                    subject.stub(:valid_input_name?) { false }

                    expect do
                        subject.inputs = { 'input1' => 'blah' }
                    end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name
                end
            end
        end

        context 'when the input value' do
            context 'contains invalid data' do
                it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value}" do
                    subject.stub(:valid_input_data?) { |data| data != 'blah' }

                    expect do
                        subject.inputs = { 'input1' => 'blah' }
                    end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value
                end
            end

            context 'is invalid' do
                it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value}" do
                    subject.stub(:valid_input_value?) { false }

                    expect do
                        subject.inputs = { 'input1' => 'blah' }
                    end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value
                end
            end
        end
    end

    describe '#valid_input_name_data?' do
        it 'returns true' do
            subject.valid_input_name_data?( 'input1' ).should be_true
        end

        context 'when the input name' do
            context 'contains invalid data' do
                it 'returns false' do
                    subject.stub(:valid_input_data?) { false }
                    subject.valid_input_name_data?( 'input1' ).should be_false
                end
            end

            context 'is invalid' do
                it 'returns false' do
                    subject.stub(:valid_input_name?) { false }
                    subject.valid_input_name_data?( 'input1' ).should be_false
                end
            end
        end
    end

    describe '#valid_input_value_data?' do
        it 'returns true' do
            subject.valid_input_value_data?( 'blah' ).should be_true
        end

        context 'when the input value' do
            context 'contains invalid data' do
                it 'returns false' do
                    subject.stub(:valid_input_data?) { false }
                    subject.valid_input_value_data?( 'blah' ).should be_false
                end
            end

            context 'is invalid' do
                it 'returns false' do
                    subject.stub(:valid_input_value?) { false }
                    subject.valid_input_value_data?( 'blah' ).should be_false
                end
            end
        end
    end

    describe '#update' do
        it 'updates the auditable inputs using the given hash' do
            a = subject.dup

            updates =   if opts[:single_input]
                            { 'input1' => 'val1' }
                        else
                            { 'input1' => 'val1', 'input2' => 'val3' }
                        end

            a.update( updates )
            a.inputs.should == updates

            if !opts[:single_input]
                c = a.dup
                c.update( input1: '1' ).update( input2: '2' )
                c['input1'].should == '1'
                c['input2'].should == '2'
            end
        end

        it 'converts all inputs to strings' do
            subject.inputs = { 'input1' => 'stuff' }
            subject.update( { 'input1' => nil } )
            subject.inputs.should == { 'input1' => '' }
        end

        it 'returns self' do
            subject.update({}).should == subject
        end

        context 'when the input name is invalid' do
            it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name}" do
                subject.stub(:valid_input_name?) { false }

                expect do
                    subject.update 'input1' => 'blah'
                end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name
            end
        end

        context 'when the input value is invalid' do
            it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value}" do
                subject.stub(:valid_input_value?) { false }

                expect do
                    subject.update 'input1' => 'blah'
                end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value
            end
        end
    end

    describe '#changes' do
        it 'returns the changes the inputs have sustained' do
            if !opts[:single_input]
                [
                    { 'input1' => 'val1', 'input2' => 'val2' },
                    { 'input2' => 'val3' },
                    {}
                ].each do |updates|
                    d = subject.dup
                    d.update( updates )
                    d.changes.should == updates
                end
            else
                [
                    { 'input1' => 'val1' },
                    { 'input1' => 'val2' },
                    {}
                ].each do |updates|
                    d = subject.dup
                    d.update( updates )
                    d.changes.should == updates
                end
            end
        end
    end

    describe '#[]' do
        it ' serves as a reader to the #auditable hash' do
            subject['input1'].should == subject.inputs['input1']
        end
    end

    describe '#[]=' do
        it 'serves as a writer to the #inputs hash' do
            subject['input1'] = 'val1'
            subject['input1'].should == 'val1'
            subject['input1'].should == subject.inputs['input1']
        end

        context 'when the input name is invalid' do
            it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name}" do
                subject.stub(:valid_input_name?) { false }

                expect do
                    subject['input1'] = 'blah'
                end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Name
            end
        end

        context 'when the input value is invalid' do
            it "raises #{Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value}" do
                subject.stub(:valid_input_value?) { false }

                expect do
                    subject['input1'] = 'blah'
                end.to raise_error Arachni::Element::Capabilities::Inputtable::Error::InvalidData::Value
            end
        end
    end

    describe '#try_input' do
        context 'when the operation is successful' do
            it 'returns true' do
                subject.try_input do
                    subject.inputs = inputs
                    nil
                end.should be_true
            end
        end

        context 'when the operation fails' do
            context 'due to an invalid name' do
                it 'returns false' do
                    subject.stub(:valid_input_name?) { false }

                    subject.try_input do
                        subject.inputs = inputs
                        true
                    end.should be_false
                end
            end
            context 'due to an invalid value' do
                it 'returns false' do
                    subject.stub(:valid_input_value?) { false }

                    subject.try_input do
                        subject.inputs = inputs
                        true
                    end.should be_false
                end
            end
        end
    end

    describe '#default_inputs' do
        it 'should be frozen' do
            subject.default_inputs.should be_frozen
        end

        context 'when #inputs' do
            context 'has been modified' do
                it 'returns original input name/vals' do
                    orig_auditable = subject.inputs.dup
                    subject.inputs = {}
                    subject.default_inputs.should == orig_auditable
                end
            end
            context 'has not been modified' do
                it 'returns #inputs' do
                    subject.default_inputs.should == subject.inputs
                end
            end
        end
    end

    describe '#dup' do
        it 'preserves #inputs' do
            dup = subject.dup
            dup.inputs.should == subject.inputs

            dup[:input1] = 'blah'
            subject.inputs['input1'].should_not == 'blah'

            dup.dup[:input1].should == 'blah'
        end
    end

    describe '#to_h' do
        it 'returns a hash representation of self' do
            hash = subject.to_h
            hash[:inputs].should         == subject.inputs
            hash[:default_inputs].should == subject.default_inputs
        end
    end

end
