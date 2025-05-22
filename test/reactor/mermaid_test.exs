defmodule Reactor.MermaidTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "basic reactor" do
    defmodule BasicReactor do
      @moduledoc false
      use Reactor
      input :whom

      step :greet, Example.Step.Greeter do
        argument :whom, input(:whom)
      end

      return :greet
    end

    expected = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.BasicReactor
        subgraph reactor_Reactor.MermaidTest.BasicReactor["Reactor.MermaidTest.BasicReactor"]
            direction LR
            input_105483575>"Input whom"]
            input_105483575 -->|whom|step_19254403
            step_19254403["greet(Example.Step.Greeter)"]
            return_Reactor.MermaidTest.BasicReactor{"Return"}
            step_19254403==>return_Reactor.MermaidTest.BasicReactor
        end
    """

    assert expected == Reactor.Mermaid.to_mermaid!(BasicReactor, output: :binary)
  end

  test "reactor with input transform" do
    defmodule ReactorWithInputTransform do
      @moduledoc false
      use Reactor

      input :whom, transform: &String.upcase/1

      step :greet, Example.Step.Greeter do
        argument :whom, input(:whom)
      end

      return :greet
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithInputTransform
        subgraph reactor_Reactor.MermaidTest.ReactorWithInputTransform["Reactor.MermaidTest.ReactorWithInputTransform"]
            direction LR
            input_47014836>"Input whom"]
            input_47014836 -->|value|step_61395349
            step_61395349[Transform input whom]
            step_61395349 -->|whom|step_33109068
            step_33109068["greet(Example.Step.Greeter)"]
            return_Reactor.MermaidTest.ReactorWithInputTransform{"Return"}
            step_33109068==>return_Reactor.MermaidTest.ReactorWithInputTransform
        end
    """

    assert plain ==
             Reactor.Mermaid.to_mermaid!(ReactorWithInputTransform, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithInputTransform
        subgraph reactor_Reactor.MermaidTest.ReactorWithInputTransform["Reactor.MermaidTest.ReactorWithInputTransform"]
            direction LR
            input_47014836>"`**Input whom**
            `"]
            input_47014836 -->|value|step_61395349
            step_61395349["`**Transform input whom**
            _&String\\.upcase/1_`"]
            step_61395349 -->|whom|step_33109068
            step_33109068["`**greet \\(Example.Step.Greeter\\)**
            `"]
            return_Reactor.MermaidTest.ReactorWithInputTransform{"Return"}
            step_33109068==>return_Reactor.MermaidTest.ReactorWithInputTransform
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithInputTransform,
               output: :binary,
               describe?: true
             )
  end

  test "reactor with inter-step dependencies" do
    defmodule ReactorWithInterStepDependencies do
      @moduledoc false
      use Reactor

      input :whom

      step :greet, Example.Step.Greeter do
        argument :whom, input(:whom)
      end

      step :greet_again, Example.Step.Greeter do
        argument :whom, result(:greet)
      end

      return :greet_again
    end

    expected = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithInterStepDependencies
        subgraph reactor_Reactor.MermaidTest.ReactorWithInterStepDependencies["Reactor.MermaidTest.ReactorWithInterStepDependencies"]
            direction LR
            input_54370523>"Input whom"]
            step_56364176 -->|whom|step_91187036
            step_91187036["greet_again(Example.Step.Greeter)"]
            input_54370523 -->|whom|step_56364176
            step_56364176["greet(Example.Step.Greeter)"]
            return_Reactor.MermaidTest.ReactorWithInterStepDependencies{"Return"}
            step_91187036==>return_Reactor.MermaidTest.ReactorWithInterStepDependencies
        end
    """

    assert expected ==
             Reactor.Mermaid.to_mermaid!(ReactorWithInterStepDependencies, output: :binary)
  end

  test "reactor with around step" do
    defmodule ReactorWithAroundStep do
      @moduledoc false
      use Reactor

      input :whom

      around :around, &around_fun/4 do
        argument :whom, input(:whom)

        step :greet, Example.Step.Greeter do
          argument :whom, input(:whom)
        end
      end

      defp around_fun(arguments, context, steps, callback) do
        callback.(arguments, context, steps)
      end
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithAroundStep
        subgraph reactor_Reactor.MermaidTest.ReactorWithAroundStep["Reactor.MermaidTest.ReactorWithAroundStep"]
            direction LR
            input_83190725>"Input whom"]
            input_83190725 -->|whom|step_114999008
            step_114999008["around(Reactor.Step.Around)"]
            subgraph reactor_99995062["{Reactor.Step.Around, :around}"]
                direction LR
                input_100859727>"Input whom"]
                input_100859727 -->|whom|step_93379368
                step_93379368["greet(Example.Step.Greeter)"]
                step_93379368 -->|greet|step_17291921
                step_17291921["{Reactor.Step.Around, :return_step}(Reactor.Step.ReturnAllArguments)"]
                return_99995062{"Return"}
                step_17291921==>return_99995062
            end
            step_114999008-->input_100859727
            return_99995062-->step_114999008
            return_Reactor.MermaidTest.ReactorWithAroundStep{"Return"}
            step_114999008==>return_Reactor.MermaidTest.ReactorWithAroundStep
        end
    """

    assert plain ==
             Reactor.Mermaid.to_mermaid!(ReactorWithAroundStep, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithAroundStep
        subgraph reactor_Reactor.MermaidTest.ReactorWithAroundStep["Reactor.MermaidTest.ReactorWithAroundStep"]
            direction LR
            input_83190725>"`**Input whom**
            `"]
            input_83190725 -->|whom|step_114999008
            step_114999008["`**around \\(Reactor.Step.Around\\)**
            _&Reactor\\.MermaidTest\\.ReactorWithAroundStep\\.fun\\_0\\_generated\\_AB119B20591598826F6DC91738CDC793/4_`"]
            subgraph reactor_99995062["{Reactor.Step.Around, :around}"]
                direction LR
                input_100859727>"`**Input whom**
                `"]
                input_100859727 -->|whom|step_93379368
                step_93379368["`**greet \\(Example.Step.Greeter\\)**
                `"]
                step_93379368 -->|greet|step_17291921
                step_17291921["`**\\{Reactor\\.Step\\.Around, :return\\_step\\} \\(Reactor.Step.ReturnAllArguments\\)**
                `"]
                return_99995062{"Return"}
                step_17291921==>return_99995062
            end
            step_114999008-->input_100859727
            return_99995062-->step_114999008
            return_Reactor.MermaidTest.ReactorWithAroundStep{"Return"}
            step_114999008==>return_Reactor.MermaidTest.ReactorWithAroundStep
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithAroundStep, output: :binary, describe?: true)
  end

  test "reactor with anon fun step" do
    defmodule ReactorWithAnonFunStep do
      @moduledoc false
      use Reactor

      step :anon do
        run &String.upcase/1
        compensate &String.upcase/1
        undo &String.downcase/1
      end
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithAnonFunStep
        subgraph reactor_Reactor.MermaidTest.ReactorWithAnonFunStep["Reactor.MermaidTest.ReactorWithAnonFunStep"]
            direction LR
            step_72959588["anon(Reactor.Step.AnonFn)"]
            return_Reactor.MermaidTest.ReactorWithAnonFunStep{"Return"}
            step_72959588==>return_Reactor.MermaidTest.ReactorWithAnonFunStep
        end
    """

    assert plain ==
             Reactor.Mermaid.to_mermaid!(ReactorWithAnonFunStep, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithAnonFunStep
        subgraph reactor_Reactor.MermaidTest.ReactorWithAnonFunStep["Reactor.MermaidTest.ReactorWithAnonFunStep"]
            direction LR
            step_72959588["`**anon \\(Reactor.Step.AnonFn\\)**
            - compensate: _&String\\.upcase/1_
            - run: _&String\\.upcase/1_
            - undo: _&String\\.downcase/1_`"]
            return_Reactor.MermaidTest.ReactorWithAnonFunStep{"Return"}
            step_72959588==>return_Reactor.MermaidTest.ReactorWithAnonFunStep
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithAnonFunStep, output: :binary, describe?: true)
  end

  test "reactor with composition" do
    defmodule ReactorWithComposition do
      @moduledoc false

      defmodule Inner do
        @moduledoc false
        use Reactor

        input :whom

        step :greet, Example.Step.Greeter do
          description "Perform a ritual greeting"
          argument :whom, input(:whom)
        end

        return :greet
      end

      defmodule Outer do
        @moduledoc false
        use Reactor

        input :first_person
        input :second_person
        input :third_person

        compose :greet_first, Inner do
          argument :whom, input(:first_person)
        end

        compose :greet_second, Inner do
          argument :whom, input(:second_person)
        end

        compose :greet_third, Inner do
          argument :whom, input(:third_person)
        end
      end
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithComposition.Outer
        subgraph reactor_Reactor.MermaidTest.ReactorWithComposition.Outer["Reactor.MermaidTest.ReactorWithComposition.Outer"]
            direction LR
            input_86645451>"Input first_person"]
            input_102627262>"Input second_person"]
            input_51322880>"Input third_person"]
            input_51322880 -->|whom|step_62090686
            step_62090686["greet_third(Reactor.Step.Compose)"]
            subgraph reactor_125465594["{Reactor.MermaidTest.ReactorWithComposition.Inner, :greet_third}"]
                direction LR
                input_16861991>"Input whom"]
                input_16861991 -->|whom|step_95294722
                step_95294722["greet(Example.Step.Greeter)"]
                return_125465594{"Return"}
                step_95294722==>return_125465594
            end
            step_62090686-->input_16861991
            return_125465594-->step_62090686
            input_102627262 -->|whom|step_12286626
            step_12286626["greet_second(Reactor.Step.Compose)"]
            subgraph reactor_71644717["{Reactor.MermaidTest.ReactorWithComposition.Inner, :greet_second}"]
                direction LR
                input_70137823>"Input whom"]
                input_70137823 -->|whom|step_37146448
                step_37146448["greet(Example.Step.Greeter)"]
                return_71644717{"Return"}
                step_37146448==>return_71644717
            end
            step_12286626-->input_70137823
            return_71644717-->step_12286626
            input_86645451 -->|whom|step_71715237
            step_71715237["greet_first(Reactor.Step.Compose)"]
            subgraph reactor_122485835["{Reactor.MermaidTest.ReactorWithComposition.Inner, :greet_first}"]
                direction LR
                input_57209917>"Input whom"]
                input_57209917 -->|whom|step_52726247
                step_52726247["greet(Example.Step.Greeter)"]
                return_122485835{"Return"}
                step_52726247==>return_122485835
            end
            step_71715237-->input_57209917
            return_122485835-->step_71715237
            return_Reactor.MermaidTest.ReactorWithComposition.Outer{"Return"}
            step_62090686==>return_Reactor.MermaidTest.ReactorWithComposition.Outer
        end
    """

    assert plain ==
             Reactor.Mermaid.to_mermaid!(ReactorWithComposition.Outer, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithComposition.Outer
        subgraph reactor_Reactor.MermaidTest.ReactorWithComposition.Outer["Reactor.MermaidTest.ReactorWithComposition.Outer"]
            direction LR
            input_86645451>"`**Input first_person**
            `"]
            input_102627262>"`**Input second_person**
            `"]
            input_51322880>"`**Input third_person**
            `"]
            input_51322880 -->|whom|step_62090686
            step_62090686["`**greet\\_third \\(Reactor.Step.Compose\\)**`"]
            subgraph reactor_125465594["{Reactor.MermaidTest.ReactorWithComposition.Inner, :greet_third}"]
                direction LR
                input_16861991>"`**Input whom**
                `"]
                input_16861991 -->|whom|step_95294722
                step_95294722["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                return_125465594{"Return"}
                step_95294722==>return_125465594
            end
            step_62090686-->input_16861991
            return_125465594-->step_62090686
            input_102627262 -->|whom|step_12286626
            step_12286626["`**greet\\_second \\(Reactor.Step.Compose\\)**`"]
            subgraph reactor_71644717["{Reactor.MermaidTest.ReactorWithComposition.Inner, :greet_second}"]
                direction LR
                input_70137823>"`**Input whom**
                `"]
                input_70137823 -->|whom|step_37146448
                step_37146448["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                return_71644717{"Return"}
                step_37146448==>return_71644717
            end
            step_12286626-->input_70137823
            return_71644717-->step_12286626
            input_86645451 -->|whom|step_71715237
            step_71715237["`**greet\\_first \\(Reactor.Step.Compose\\)**`"]
            subgraph reactor_122485835["{Reactor.MermaidTest.ReactorWithComposition.Inner, :greet_first}"]
                direction LR
                input_57209917>"`**Input whom**
                `"]
                input_57209917 -->|whom|step_52726247
                step_52726247["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                return_122485835{"Return"}
                step_52726247==>return_122485835
            end
            step_71715237-->input_57209917
            return_122485835-->step_71715237
            return_Reactor.MermaidTest.ReactorWithComposition.Outer{"Return"}
            step_62090686==>return_Reactor.MermaidTest.ReactorWithComposition.Outer
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithComposition.Outer,
               output: :binary,
               describe?: true
             )
  end

  test "reactor with group" do
    defmodule ReactorWithGroup do
      @moduledoc false
      use Reactor

      input :whom

      group :group do
        argument :whom, input(:whom)
        before_all &do_before_all/3
        after_all &do_after_all/1

        step :greet, Example.Step.Greeter do
          description "Perform a ritual greeting"
          argument :whom, input(:whom)
        end
      end

      defp do_before_all(args, context, steps),
        do: {:ok, args, context, steps}

      defp do_after_all(result), do: {:ok, result}
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithGroup
        subgraph reactor_Reactor.MermaidTest.ReactorWithGroup["Reactor.MermaidTest.ReactorWithGroup"]
            direction LR
            input_54126149>"Input whom"]
            input_54126149 -->|whom|step_93872833
            step_93872833["group(Reactor.Step.Group)"]
            subgraph reactor_66320023["{Reactor.Step.Group, :group}"]
                direction LR
                input_86369158>"Input whom"]
                input_86369158 -->|whom|step_112784955
                step_112784955["greet(Example.Step.Greeter)"]
                step_112784955 -->|greet|step_85556533
                step_85556533["{Reactor.Step.Group, :return_step}(Reactor.Step.ReturnAllArguments)"]
                return_66320023{"Return"}
                step_85556533==>return_66320023
            end
            step_93872833-->input_86369158
            return_66320023-->step_93872833
            return_Reactor.MermaidTest.ReactorWithGroup{"Return"}
            step_93872833==>return_Reactor.MermaidTest.ReactorWithGroup
        end
    """

    assert plain == Reactor.Mermaid.to_mermaid!(ReactorWithGroup, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithGroup
        subgraph reactor_Reactor.MermaidTest.ReactorWithGroup["Reactor.MermaidTest.ReactorWithGroup"]
            direction LR
            input_54126149>"`**Input whom**
            `"]
            input_54126149 -->|whom|step_93872833
            step_93872833["`**group \\(Reactor.Step.Group\\)**
            - after: _&Reactor\\.MermaidTest\\.ReactorWithGroup\\.after\\_all\\_0\\_generated\\_03884852E6C41147D8A2F4C0B16C98F0/1_
            - before: _&Reactor\\.MermaidTest\\.ReactorWithGroup\\.before\\_all\\_0\\_generated\\_FA2B8A4BC9AC4CB8EA4E7BC9C89643D7/3_`"]
            subgraph reactor_66320023["{Reactor.Step.Group, :group}"]
                direction LR
                input_86369158>"`**Input whom**
                `"]
                input_86369158 -->|whom|step_112784955
                step_112784955["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                step_112784955 -->|greet|step_85556533
                step_85556533["`**\\{Reactor\\.Step\\.Group, :return\\_step\\} \\(Reactor.Step.ReturnAllArguments\\)**
                `"]
                return_66320023{"Return"}
                step_85556533==>return_66320023
            end
            step_93872833-->input_86369158
            return_66320023-->step_93872833
            return_Reactor.MermaidTest.ReactorWithGroup{"Return"}
            step_93872833==>return_Reactor.MermaidTest.ReactorWithGroup
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithGroup, output: :binary, describe?: true)
  end

  test "reactor with map" do
    defmodule ReactorWithMap do
      @moduledoc false
      use Reactor

      input :whom

      map :greetings do
        source input(:whom)

        step :greet, Example.Step.Greeter do
          description "Perform a ritual greeting"
          argument :whom, element(:greetings)
        end
      end
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithMap
        subgraph reactor_Reactor.MermaidTest.ReactorWithMap["Reactor.MermaidTest.ReactorWithMap"]
            direction LR
            input_70555545>"Input whom"]
            input_70555545 -->|source|step_36016958
            step_36016958["greetings(Reactor.Step.Map)"]
            subgraph reactor_53997923["{Reactor.Step.Map.Mermaid, :greetings}"]
                direction LR
                input_119882032>"Input source"]
                input_119882032 -->|whom|step_45902516
                step_45902516["greet(Example.Step.Greeter)"]
                return_53997923{"Return"}
                step_45902516==>return_53997923
            end
            step_36016958-->input_119882032
            return_53997923-->step_36016958
            return_Reactor.MermaidTest.ReactorWithMap{"Return"}
            step_36016958==>return_Reactor.MermaidTest.ReactorWithMap
        end
    """

    assert plain == Reactor.Mermaid.to_mermaid!(ReactorWithMap, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithMap
        subgraph reactor_Reactor.MermaidTest.ReactorWithMap["Reactor.MermaidTest.ReactorWithMap"]
            direction LR
            input_70555545>"`**Input whom**
            `"]
            input_70555545 -->|source|step_36016958
            step_36016958["`**greetings \\(Reactor.Step.Map\\)**`"]
            subgraph reactor_53997923["{Reactor.Step.Map.Mermaid, :greetings}"]
                direction LR
                input_119882032>"`**Input source**
                `"]
                input_119882032 -->|whom|step_45902516
                step_45902516["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                return_53997923{"Return"}
                step_45902516==>return_53997923
            end
            step_36016958-->input_119882032
            return_53997923-->step_36016958
            return_Reactor.MermaidTest.ReactorWithMap{"Return"}
            step_36016958==>return_Reactor.MermaidTest.ReactorWithMap
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithMap, output: :binary, describe?: true)
  end

  test "reactor with switch" do
    defmodule ReactorWithSwitch do
      @moduledoc false
      use Reactor

      input :maybe_truthy

      switch :switch do
        on input(:maybe_truthy)

        matches? &(!!&1) do
          step :greet, Example.Step.Greeter do
            description "Perform a ritual greeting"
            argument :whom, value("World")
          end
        end

        default do
          flunk :fail, "No one to greet!"
        end
      end
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithSwitch
        subgraph reactor_Reactor.MermaidTest.ReactorWithSwitch["Reactor.MermaidTest.ReactorWithSwitch"]
            direction LR
            input_62094121>"Input maybe_truthy"]
            input_62094121 -->|value|step_94911623
            step_94911623["switch(Reactor.Step.Switch)"]
            step_94911623_decision@{shape: diamond, label: "Decision for switch"}
            step_94911623-->step_94911623_decision
            step_94911623_decision-->step_40606384
            step_94911623_decision-->step_69352850
            subgraph step_40606384["default branch of switch"]
                step_64306052["{:fail, :arguments}(Reactor.Step.ReturnAllArguments)"]
                step_64306052 -->|arguments|step_71585845
                value_10391594{{"`&quot;No one to greet\\!&quot;`"}}
                value_10391594 -->|message|step_71585845
                step_71585845["fail(Reactor.Step.Fail)"]
                direction LR
            end
            subgraph step_69352850["match branch of switch"]
                value_World{{"`&quot;World&quot;`"}}
                value_World -->|whom|step_52846662
                step_52846662["greet(Example.Step.Greeter)"]
                direction LR
            end
            return_Reactor.MermaidTest.ReactorWithSwitch{"Return"}
            step_94911623==>return_Reactor.MermaidTest.ReactorWithSwitch
        end
    """

    assert plain == Reactor.Mermaid.to_mermaid!(ReactorWithSwitch, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithSwitch
        subgraph reactor_Reactor.MermaidTest.ReactorWithSwitch["Reactor.MermaidTest.ReactorWithSwitch"]
            direction LR
            input_62094121>"`**Input maybe_truthy**
            `"]
            input_62094121 -->|value|step_94911623
            step_94911623["`**switch \\(Reactor.Step.Switch\\)**`"]
            step_94911623_decision@{shape: diamond, label: "Decision for switch"}
            step_94911623-->step_94911623_decision
            step_94911623_decision-->step_40606384
            step_94911623_decision-->step_69352850
            subgraph step_40606384["default branch of switch"]
                step_64306052["`**\\{:fail, :arguments\\} \\(Reactor.Step.ReturnAllArguments\\)**
                `"]
                step_64306052 -->|arguments|step_71585845
                value_10391594{{"`&quot;No one to greet\\!&quot;`"}}
                value_10391594 -->|message|step_71585845
                step_71585845["`**fail \\(Reactor.Step.Fail\\)**
                `"]
                direction LR
            end
            subgraph step_69352850["`match branch of switch
            _&Reactor\\.MermaidTest\\.ReactorWithSwitch\\.predicate\\_0\\_generated\\_E5CBC1E5147E30A8DA7DF7C06141D07E/1_`"]
                value_World{{"`&quot;World&quot;`"}}
                value_World -->|whom|step_52846662
                step_52846662["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                direction LR
            end
            return_Reactor.MermaidTest.ReactorWithSwitch{"Return"}
            step_94911623==>return_Reactor.MermaidTest.ReactorWithSwitch
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithSwitch, output: :binary, describe?: true)
  end

  test "reactor with recurse" do
    defmodule ReactorWithRecurse do
      @moduledoc false

      defmodule Inner do
        @moduledoc false
        use Reactor

        input :whom

        step :greet, Example.Step.Greeter do
          description "Perform a ritual greeting"
          argument :whom, input(:whom)
        end

        return :greet
      end

      defmodule Outer do
        @moduledoc false
        use Reactor

        input :first_person

        recurse :greet_first, Inner do
          argument :whom, input(:first_person)
          max_iterations 9
          exit_condition fn str -> String.length(str) > 0 end
        end
      end
    end

    plain = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithRecurse.Outer
        subgraph reactor_Reactor.MermaidTest.ReactorWithRecurse.Outer["Reactor.MermaidTest.ReactorWithRecurse.Outer"]
            direction LR
            input_106935667>"Input first_person"]
            input_106935667 -->|whom|step_67615159
            step_67615159["greet_first(Reactor.Step.Recurse)"]
            subgraph reactor_11439297["{Reactor.MermaidTest.ReactorWithRecurse.Inner, :greet_first}"]
                direction LR
                input_34140751>"Input whom"]
                input_34140751 -->|whom|step_131748215
                step_131748215["greet(Example.Step.Greeter)"]
                return_11439297{"Return"}
                step_131748215==>return_11439297
            end
            step_67615159-->input_34140751
            return_11439297-->step_67615159
            return_Reactor.MermaidTest.ReactorWithRecurse.Outer{"Return"}
            step_67615159==>return_Reactor.MermaidTest.ReactorWithRecurse.Outer
        end
    """

    assert plain ==
             Reactor.Mermaid.to_mermaid!(ReactorWithRecurse.Outer, output: :binary)

    expanded = """
    flowchart LR
        start{"Start"}
        start==>reactor_Reactor.MermaidTest.ReactorWithRecurse.Outer
        subgraph reactor_Reactor.MermaidTest.ReactorWithRecurse.Outer["Reactor.MermaidTest.ReactorWithRecurse.Outer"]
            direction LR
            input_106935667>"`**Input first_person**
            `"]
            input_106935667 -->|whom|step_67615159
            step_67615159["`**greet\\_first \\(Reactor.Step.Recurse\\)**
             max_iterations: 9`"]
            subgraph reactor_11439297["{Reactor.MermaidTest.ReactorWithRecurse.Inner, :greet_first}"]
                direction LR
                input_34140751>"`**Input whom**
                `"]
                input_34140751 -->|whom|step_131748215
                step_131748215["`**greet \\(Example.Step.Greeter\\)**
                Perform a ritual greeting`"]
                return_11439297{"Return"}
                step_131748215==>return_11439297
            end
            step_67615159-->input_34140751
            return_11439297-->step_67615159
            return_Reactor.MermaidTest.ReactorWithRecurse.Outer{"Return"}
            step_67615159==>return_Reactor.MermaidTest.ReactorWithRecurse.Outer
        end
    """

    assert expanded ==
             Reactor.Mermaid.to_mermaid!(ReactorWithRecurse.Outer,
               output: :binary,
               describe?: true
             )
  end
end
